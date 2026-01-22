# =============================================================================
# main.py - Budget App AI Analysis Proxy Server (FastAPI)
# =============================================================================
# #17: device_id 기반 일일 3회 제한
# #13: 잔여 기간 지출 계획 조언 추가
# DB 추상화: SQLite(기본) / PostgreSQL(DATABASE_URL 환경변수로 전환)
# =============================================================================
from fastapi import FastAPI, HTTPException, Header, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from typing import Optional
from collections import defaultdict
import httpx
import os
import re
import json
import uuid
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from dotenv import load_dotenv

# 데이터베이스 추상화 레이어 import
from database import create_database, get_today_kst

# 환경변수 로드
load_dotenv()

app = FastAPI(title="Budget AI API", version="2.1.0")

# =============================================================================
# CORS 설정 (보안 강화)
# =============================================================================
# 환경변수에서 허용 도메인 로드 (쉼표로 구분)
# 예: ALLOWED_ORIGINS=https://myapp.com,https://app.myapp.com
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "").split(",")
# 빈 문자열 제거
ALLOWED_ORIGINS = [origin.strip() for origin in ALLOWED_ORIGINS if origin.strip()]

# 개발 환경용 기본값 (프로덕션에서는 반드시 ALLOWED_ORIGINS 환경변수 설정 필요)
if not ALLOWED_ORIGINS:
    # 개발 환경: localhost만 허용
    ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["GET", "POST"],  # 필요한 메서드만 허용
    allow_headers=["Content-Type", "Authorization", "X-Admin-Key"],  # 필요한 헤더만 허용
)

# Gemini API 설정
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = "gemini-2.5-flash-lite-preview-09-2025"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

# =============================================================================
# 관리자 인증 설정
# =============================================================================
# 관리자 API 키 (로그 조회 등 관리 기능 접근용)
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY")

def verify_admin_key(x_admin_key: str = Header(None, alias="X-Admin-Key")) -> bool:
    """관리자 API 키 검증"""
    # ADMIN_API_KEY 미설정 시 관리 기능 비활성화
    if not ADMIN_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Admin API is not configured"
        )
    # API 키 검증
    if not x_admin_key or x_admin_key != ADMIN_API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing admin API key"
        )
    return True

# #17: 일일 분석 횟수 제한
DAILY_LIMIT = 3
KST = ZoneInfo("Asia/Seoul")

# =============================================================================
# IP 기반 Rate Limiting (분당 요청 제한)
# =============================================================================
# 분당 최대 요청 수
IP_RATE_LIMIT_PER_MINUTE = int(os.getenv("IP_RATE_LIMIT_PER_MINUTE", "10"))
# IP별 요청 기록 저장 (메모리 기반, 프로덕션에서는 Redis 권장)
ip_request_times: dict[str, list[float]] = defaultdict(list)

def get_client_ip(request: Request) -> str:
    """클라이언트 IP 추출 (프록시 고려)"""
    # X-Forwarded-For 헤더 확인 (프록시/로드밸런서 뒤에 있는 경우)
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        # 첫 번째 IP가 실제 클라이언트 IP
        return forwarded.split(",")[0].strip()
    # X-Real-IP 헤더 확인
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    # 직접 연결된 클라이언트 IP
    return request.client.host if request.client else "unknown"

def check_ip_rate_limit(ip: str) -> bool:
    """IP별 분당 요청 제한 확인"""
    now = time.time()
    minute_ago = now - 60
    # 1분 이내 요청만 유지
    ip_request_times[ip] = [t for t in ip_request_times[ip] if t > minute_ago]
    # 제한 확인
    if len(ip_request_times[ip]) >= IP_RATE_LIMIT_PER_MINUTE:
        return False
    # 현재 요청 기록
    ip_request_times[ip].append(now)
    return True

def cleanup_ip_records():
    """오래된 IP 기록 정리 (메모리 관리)"""
    now = time.time()
    minute_ago = now - 60
    # 빈 기록 제거
    empty_ips = [ip for ip, times in ip_request_times.items() if not times or all(t <= minute_ago for t in times)]
    for ip in empty_ips:
        del ip_request_times[ip]

# =============================================================================
# 데이터베이스 초기화 (SQLite 또는 PostgreSQL)
# =============================================================================
# DATABASE_URL 환경변수가 있으면 PostgreSQL, 없으면 SQLite 사용
db = create_database()
db.init_db()

# =============================================================================
# NSFW 필터 설정 (강화된 버전)
# =============================================================================
import unicodedata

NSFW_KEYWORDS = [
    # 욕설/비속어 (한국어)
    "시발", "씨발", "병신", "지랄", "새끼", "개새끼", "미친", "존나", "좆",
    # 욕설/비속어 (영어)
    "fuck", "shit", "bitch", "asshole", "bastard", "damn",
    # 욕설/비속어 (일본어)
    "くそ", "ちくしょう", "馬鹿",
]

# 한글 자모 분리 변형 패턴 (예: "시ㅂ발" → "시발")
KOREAN_JAMO_VARIANTS = {
    "ㅅㅣㅂㅏㄹ": "시발", "ㅆㅣㅂㅏㄹ": "씨발",
    "ㅂㅕㅇㅅㅣㄴ": "병신", "ㅈㅣㄹㅏㄹ": "지랄",
    "ㅅㅐㄲㅣ": "새끼", "ㅈㅗㄴㄴㅏ": "존나",
}

# 공백/특수문자 삽입 우회 탐지용 정규식 패턴
def _create_spaced_pattern(word: str) -> str:
    """단어 사이에 공백/특수문자가 삽입된 패턴 생성"""
    # 각 글자 사이에 선택적 공백/특수문자 허용
    chars = list(word)
    pattern = r"[\s\.\-_]*".join(re.escape(c) for c in chars)
    return pattern

# 정규화된 NSFW 패턴 (공백 삽입 우회 탐지)
NSFW_PATTERNS = [re.compile(_create_spaced_pattern(kw), re.IGNORECASE) for kw in NSFW_KEYWORDS]

def _normalize_text(text: str) -> str:
    """텍스트 정규화 (유니코드 정규화 + 공백 제거)"""
    # 유니코드 정규화 (NFC: 조합형으로 통일)
    normalized = unicodedata.normalize("NFC", text)
    return normalized

def _normalize_korean_jamo(text: str) -> str:
    """한글 자모 분리 변형 복원"""
    result = text
    for variant, original in KOREAN_JAMO_VARIANTS.items():
        result = result.replace(variant, original)
    return result

def filter_nsfw_input(text: str) -> str:
    """입력 텍스트에서 NSFW 콘텐츠 필터링 (강화 버전)"""
    # 1. 유니코드 정규화
    filtered = _normalize_text(text)
    # 2. 한글 자모 변형 복원
    filtered = _normalize_korean_jamo(filtered)
    # 3. 기본 키워드 필터링
    for keyword in NSFW_KEYWORDS:
        pattern = re.compile(re.escape(keyword), re.IGNORECASE)
        filtered = pattern.sub("***", filtered)
    # 4. 공백 삽입 우회 패턴 필터링
    for pattern in NSFW_PATTERNS:
        filtered = pattern.sub("***", filtered)
    return filtered

def filter_nsfw_output(result: dict) -> dict:
    """출력 결과에서 NSFW 콘텐츠 필터링"""
    def filter_text(text: str) -> str:
        for keyword in NSFW_KEYWORDS:
            pattern = re.compile(re.escape(keyword), re.IGNORECASE)
            text = pattern.sub("***", text)
        return text

    def filter_list(items: list) -> list:
        return [filter_text(item) if isinstance(item, str) else item for item in items]

    if "oneLiner" in result:
        result["oneLiner"] = filter_text(result["oneLiner"])
    if "summary" in result:
        result["summary"] = filter_text(result["summary"])
    if "insights" in result:
        result["insights"] = filter_list(result["insights"])
    if "warnings" in result:
        result["warnings"] = filter_list(result["warnings"])
    if "suggestions" in result:
        result["suggestions"] = filter_list(result["suggestions"])
    # #13: 새로운 필드
    if "spendingPlan" in result:
        result["spendingPlan"] = filter_text(result["spendingPlan"])

    return result

# =============================================================================
# 응답 톤 설정 (다국어)
# =============================================================================
TONE_PROMPTS = {
    "ko": {
        "gentle": "온화하고 부드러운 어조로, 사용자를 배려하며 친근하게 조언해주세요.",
        "praise": "칭찬과 격려를 아끼지 않는 긍정적인 어조로, 잘한 점을 부각시켜주세요.",
        "factual": "객관적이고 직설적인 어조로, 팩트 기반의 냉정한 분석을 제공해주세요. 감정적 표현 없이 현실을 직시하게 해주세요.",
        "coach": "코치처럼 동기부여하는 어조로, 목표 달성을 위한 구체적인 방향을 제시해주세요.",
        "humorous": "유머러스하고 재치있는 어조로, 가벼운 농담을 섞어 분석해주세요.",
    },
    "en": {
        "gentle": "Use a warm and gentle tone, being considerate and friendly in your advice.",
        "praise": "Use a positive and encouraging tone, highlighting what the user is doing well.",
        "factual": "Use an objective and direct tone, providing cold, fact-based analysis without emotional expressions.",
        "coach": "Use a motivating coach-like tone, providing specific directions for achieving goals.",
        "humorous": "Use a humorous and witty tone, mixing in light jokes with your analysis.",
    },
    "ja": {
        "gentle": "温かく優しい口調で、ユーザーに配慮しながら親しみやすくアドバイスしてください。",
        "praise": "褒めることを惜しまない前向きな口調で、良い点を強調してください。",
        "factual": "客観的で直接的な口調で、感情的な表現なしに事実に基づいた冷静な分析を提供してください。",
        "coach": "コーチのようにモチベーションを高める口調で、目標達成のための具体的な方向性を示してください。",
        "humorous": "ユーモラスで機知に富んだ口調で、軽いジョークを交えながら分析してください。",
    },
}

# 한 마디 요약용 강한 톤 프롬프트 (oneLiner 전용 - 극단적으로 스타일 반영)
ONE_LINER_TONE_PROMPTS = {
    "ko": {
        "gentle": "따뜻하게 위로하고 감싸주는 다정한 한 마디 (예: '충분히 잘하고 있어요, 조금씩 나아지면 돼요~')",
        "praise": "열렬히 칭찬하고 응원하는 한 마디 (예: '와! 정말 대단해요! 이 정도면 재테크 고수!')",
        "factual": "뼈 때리는 팩폭 한 마디, 현실을 냉정하게 직시시키는 독설 (예: '솔직히? 이러다 거지됩니다.')",
        "coach": "강력하게 동기부여하는 한 마디 (예: '지금이 바로 변화할 때입니다! 할 수 있어요!')",
        "humorous": "빵 터지는 재치있는 농담 한 마디 (예: '지갑이 다이어트 중이시네요~ 곧 식스팩 나오겠어요!')",
    },
    "en": {
        "gentle": "A warm, comforting one-liner (e.g., 'You're doing fine, take it one step at a time~')",
        "praise": "An enthusiastic praise (e.g., 'Wow! You're absolutely crushing it! Financial genius!')",
        "factual": "A brutally honest reality check (e.g., 'Honestly? Keep this up and you're going broke.')",
        "coach": "A powerful motivational punch (e.g., 'Now is the time to change! You've got this!')",
        "humorous": "A hilarious witty joke (e.g., 'Your wallet is on a diet~ Six-pack abs coming soon!')",
    },
    "ja": {
        "gentle": "温かく慰めてくれる一言（例：'十分頑張っていますよ、少しずつで大丈夫~'）",
        "praise": "熱烈に褒めてくれる一言（例：'すごい！これは財テクの達人レベル！'）",
        "factual": "痛い事実を突きつける一言（例：'正直に言うと？このままだと破産しますよ。'）",
        "coach": "強力にモチベーションを高める一言（例：'今こそ変わる時です！できます！'）",
        "humorous": "思わず笑ってしまう一言（例：'お財布がダイエット中ですね～もうすぐシックスパック！'）",
    },
}

# =============================================================================
# 프롬프트 설정 (다국어) - #13: 잔여 기간 지출 계획 조언 추가
# =============================================================================
SYSTEM_PROMPTS = {
    "ko": """당신은 개인 가계부 데이터를 분석하는 전문 재무 상담 AI입니다.
제공된 가계부 데이터를 분석하고 실행 가능한 인사이트를 제공해주세요.
소비 패턴, 절약 가능성, 재정 건전성에 초점을 맞춰주세요.

[응답 스타일]
{tone}

[주의사항]
- 부적절하거나 불쾌한 표현을 절대 사용하지 마세요.
- 전문적이고 건전한 재무 조언만 제공하세요.
- 반드시 한국어로 응답하세요.""",

    "en": """You are a professional financial advisor AI that analyzes personal budget data.
Analyze the provided budget data and provide actionable insights.
Focus on spending patterns, potential savings, and financial health.

[Response Style]
{tone}

[Important Notes]
- Never use inappropriate or offensive language.
- Only provide professional and sound financial advice.
- You must respond in English.""",

    "ja": """あなたは個人の予算データを分析するプロのファイナンシャルアドバイザーAIです。
提供された予算データを分析し、実用的な洞察を提供してください。
支出パターン、節約の可能性、財務の健全性に焦点を当ててください。

[応答スタイル]
{tone}

[注意事項]
- 不適切または不快な表現は絶対に使用しないでください。
- 専門的で健全な財務アドバイスのみを提供してください。
- 必ず日本語で回答してください。"""
}

# #13: 잔여 기간 지출 계획 조언을 포함한 분석 템플릿
ANALYSIS_TEMPLATES = {

    "ko": """다음 가계부 데이터를 분석하고 JSON 형식으로 응답해주세요:

{data}

[중요] oneLiner는 반드시 다음 스타일로 작성하세요: {one_liner_tone}

아래의 JSON 구조로 응답해주세요:
{{
  "oneLiner": "한 마디 요약 - 위 스타일을 극단적으로 반영한 짧고 강렬한 한 문장",
  "summary": "전체 재정 상태 요약 (2-3문장)",
  "insights": ["핵심 인사이트 1", "핵심 인사이트 2", "핵심 인사이트 3"],
  "warnings": ["과소비나 우려 사항에 대한 경고"],
  "suggestions": ["구체적인 개선 제안 1", "제안 2"],
  "spendingPlan": "남은 기간 동안의 구체적인 지출 계획 조언 (예: '남은 15일간 하루 평균 3만원 이내로 지출하면 예산 내 유지 가능합니다. 식비는 2만원, 기타 1만원으로 배분하세요.')",
  "pattern": {{
    "mainCategory": "가장 지출이 많은 카테고리",
    "spendingTrend": "increasing/decreasing/stable",
    "savingPotential": 10000,
    "riskLevel": "low/medium/high"
  }}
}}""",

    "en": """Please analyze the following budget data and respond in JSON format:

{data}

[IMPORTANT] The oneLiner MUST be written in this style: {one_liner_tone}

Respond with this exact JSON structure:
{{
  "oneLiner": "One-liner summary - A short, punchy sentence that STRONGLY reflects the above style",
  "summary": "Overall financial status summary in 2-3 sentences",
  "insights": ["Key insight 1", "Key insight 2", "Key insight 3"],
  "warnings": ["Warning about overspending or concerns"],
  "suggestions": ["Specific actionable suggestion 1", "Suggestion 2"],
  "spendingPlan": "Specific spending plan advice for the remaining period (e.g., 'For the remaining 15 days, keep daily spending under $30 to stay within budget. Allocate $20 for food and $10 for other expenses.')",
  "pattern": {{
    "mainCategory": "Category with highest spending",
    "spendingTrend": "increasing/decreasing/stable",
    "savingPotential": 10000,
    "riskLevel": "low/medium/high"
  }}
}}""",

    "ja": """以下の家計簿データを分析し、JSON形式で回答してください：

{data}

[重要] oneLinerは必ず次のスタイルで書いてください：{one_liner_tone}

以下のJSON構造で回答してください：
{{
  "oneLiner": "一言まとめ - 上記のスタイルを極端に反映した短くてインパクトのある一文",
  "summary": "全体的な財務状況の要約（2-3文）",
  "insights": ["重要な洞察1", "重要な洞察2", "重要な洞察3"],
  "warnings": ["過支出や懸念事項についての警告"],
  "suggestions": ["具体的な改善提案1", "提案2"],
  "spendingPlan": "残りの期間の具体的な支出計画アドバイス（例：'残り15日間、1日平均3万円以内に抑えれば予算内で収まります。食費2万円、その他1万円に配分してください。'）",
  "pattern": {{
    "mainCategory": "最も支出が多いカテゴリー",
    "spendingTrend": "increasing/decreasing/stable",
    "savingPotential": 10000,
    "riskLevel": "low/medium/high"
  }}
}}"""
}

# =============================================================================
# #17: 에러 메시지 (다국어)
# =============================================================================
ERROR_MESSAGES = {
    "ko": {
        "rate_limit": "오늘의 분석 횟수({count}/{limit})를 모두 사용했습니다. 내일 다시 시도해주세요.",
        "device_id_required": "기기 식별자가 필요합니다.",
        "api_key_missing": "서버 설정 오류: API 키가 구성되지 않았습니다.",
        "gemini_error": "AI 분석 중 오류가 발생했습니다: {detail}",
        "parse_error": "AI 응답을 처리하는 중 오류가 발생했습니다.",
        "network_error": "네트워크 오류: {detail}",
    },
    "en": {
        "rate_limit": "You've used all analysis attempts for today ({count}/{limit}). Please try again tomorrow.",
        "device_id_required": "Device identifier is required.",
        "api_key_missing": "Server configuration error: API key not configured.",
        "gemini_error": "Error during AI analysis: {detail}",
        "parse_error": "Error processing AI response.",
        "network_error": "Network error: {detail}",
    },
    "ja": {
        "rate_limit": "本日の分析回数({count}/{limit})を使い切りました。明日もう一度お試しください。",
        "device_id_required": "デバイス識別子が必要です。",
        "api_key_missing": "サーバー設定エラー：APIキーが設定されていません。",
        "gemini_error": "AI分析中にエラーが発生しました：{detail}",
        "parse_error": "AI応答の処理中にエラーが発生しました。",
        "network_error": "ネットワークエラー：{detail}",
    },
}

def get_error_message(key: str, language: str, **kwargs) -> str:
    """다국어 에러 메시지 반환"""
    messages = ERROR_MESSAGES.get(language, ERROR_MESSAGES["ko"])
    message = messages.get(key, ERROR_MESSAGES["ko"].get(key, key))
    return message.format(**kwargs) if kwargs else message

# =============================================================================
# Device ID 검증 함수
# =============================================================================
def validate_device_id(device_id: str) -> bool:
    """UUID v4 형식 검증"""
    if not device_id or len(device_id) > 50:  # 길이 제한
        return False
    try:
        # UUID 형식 검증
        uuid_obj = uuid.UUID(device_id, version=4)
        return str(uuid_obj) == device_id.lower()
    except ValueError:
        return False

# =============================================================================
# 요청/응답 모델
# =============================================================================
class AnalyzeRequest(BaseModel):
    data: str
    language: str = "ko"
    tone: str = "gentle"  # gentle, praise, factual, coach, humorous
    device_id: str  # #17: 기기 고유 식별자 (필수, UUID v4 형식)

    # Device ID 검증 (Pydantic v2)
    @field_validator('device_id')
    @classmethod
    def validate_device_id_format(cls, v: str) -> str:
        if not validate_device_id(v):
            raise ValueError('Invalid device_id format. Must be UUID v4.')
        return v.lower()  # 소문자로 정규화

class PatternResponse(BaseModel):
    mainCategory: str
    spendingTrend: str
    savingPotential: int
    riskLevel: str

class AnalyzeResponse(BaseModel):
    oneLiner: str  # 한 마디 요약 (톤 강하게 반영)
    summary: str
    insights: list[str]
    warnings: list[str]
    suggestions: list[str]
    spendingPlan: str  # #13: 잔여 기간 지출 계획 조언
    pattern: PatternResponse
    remainingAnalyses: int  # #17: 남은 분석 횟수

# #17: 사용량 조회 응답
class UsageResponse(BaseModel):
    device_id: str
    date: str
    count: int
    limit: int
    remaining: int

# =============================================================================
# API 엔드포인트
# =============================================================================
@app.get("/health")
async def health_check():
    """헬스 체크"""
    # API 키 존재 여부는 노출하지 않음 (보안)
    return {"status": "ok"}

@app.get("/api/tones")
async def get_tones():
    """사용 가능한 톤 목록 반환"""
    return {
        "tones": ["gentle", "praise", "factual", "coach", "humorous"],
        "descriptions": TONE_PROMPTS
    }

# #17: 사용량 조회 API
@app.get("/api/usage/{device_id}", response_model=UsageResponse)
async def get_usage(device_id: str):
    """현재 사용량 조회"""
    # Device ID 형식 검증 (UUID v4)
    if not validate_device_id(device_id):
        raise HTTPException(
            status_code=400,
            detail="Invalid device_id format. Must be UUID v4."
        )
    device_id = device_id.lower()  # 소문자로 정규화
    count = db.get_usage_count(device_id)
    return UsageResponse(
        device_id=device_id,
        date=get_today_kst(),
        count=count,
        limit=DAILY_LIMIT,
        remaining=max(0, DAILY_LIMIT - count)
    )

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest, request: Request):
    """AI 가계부 분석 (#17: 일일 3회 제한 적용, IP Rate Limiting 추가)"""
    # device_id 형식은 Pydantic에서 자동 검증 (UUID v4)

    # IP 기반 분당 요청 제한 확인
    client_ip = get_client_ip(request)
    if not check_ip_rate_limit(client_ip):
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please wait a moment.",
            headers={"Retry-After": "60"}
        )

    # 주기적으로 IP 기록 정리 (매 요청마다 실행, 가벼운 작업)
    cleanup_ip_records()

    # #17: 일일 사용량 확인
    current_count = db.get_usage_count(req.device_id)
    if current_count >= DAILY_LIMIT:
        # 요청 로그 저장 (Rate Limit)
        db.save_analysis_log(
            device_id=req.device_id,
            language=req.language,
            tone=req.tone,
            request_data=req.data,
            status_code=429,
            error_message=f"Rate limit exceeded: {current_count}/{DAILY_LIMIT}"
        )
        raise HTTPException(
            status_code=429,  # Too Many Requests
            detail=get_error_message("rate_limit", req.language, count=current_count, limit=DAILY_LIMIT)
        )

    # API 키 확인
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail=get_error_message("api_key_missing", req.language)
        )

    # NSFW 필터링 (입력)
    filtered_data = filter_nsfw_input(req.data)

    # 언어별 톤 프롬프트 가져오기
    tone_prompts = TONE_PROMPTS.get(req.language, TONE_PROMPTS["ko"])
    tone_text = tone_prompts.get(req.tone, tone_prompts["gentle"])

    # 한 마디 요약용 강한 톤 프롬프트 가져오기
    one_liner_prompts = ONE_LINER_TONE_PROMPTS.get(req.language, ONE_LINER_TONE_PROMPTS["ko"])
    one_liner_tone = one_liner_prompts.get(req.tone, one_liner_prompts["gentle"])

    # 언어별 프롬프트 생성
    system_prompt = SYSTEM_PROMPTS.get(req.language, SYSTEM_PROMPTS["ko"]).format(tone=tone_text)
    analysis_prompt = ANALYSIS_TEMPLATES.get(req.language, ANALYSIS_TEMPLATES["ko"]).format(
        data=filtered_data,
        one_liner_tone=one_liner_tone
    )

    # Gemini API 호출
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(
                GEMINI_URL,  # URL에서 API 키 제거
                headers={"x-goog-api-key": GEMINI_API_KEY},  # 헤더로 API 키 전송 (보안 강화)
                json={
                    "contents": [{
                        "role": "user",
                        "parts": [
                            {"text": system_prompt},
                            {"text": analysis_prompt}
                        ]
                    }],
                    "generationConfig": {
                        "temperature": 0.7,
                        "topK": 40,
                        "topP": 0.95,
                        "maxOutputTokens": 2048,
                        "responseMimeType": "application/json"
                    },
                    "safetySettings": [
                        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                    ]
                }
            )

            if response.status_code != 200:
                error_data = response.json()
                # 상세 에러는 로그에만 저장 (보안: 사용자에게 노출하지 않음)
                internal_detail = error_data.get("error", {}).get("message", "Unknown error")
                # 요청 로그 저장 (Gemini API 에러)
                db.save_analysis_log(
                    device_id=req.device_id,
                    language=req.language,
                    tone=req.tone,
                    request_data=req.data,
                    status_code=response.status_code,
                    error_message=f"Gemini API error: {internal_detail}"
                )
                # 사용자에게는 일반화된 에러 메시지만 반환
                raise HTTPException(
                    status_code=502,  # Bad Gateway (외부 API 에러)
                    detail=get_error_message("gemini_error", req.language, detail="AI 서비스 일시 오류")
                )

            result = response.json()
            text = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")

            if not text:
                # 요청 로그 저장 (빈 응답)
                db.save_analysis_log(
                    device_id=req.device_id,
                    language=req.language,
                    tone=req.tone,
                    request_data=req.data,
                    status_code=500,
                    error_message="Empty response from Gemini API"
                )
                raise HTTPException(
                    status_code=500,
                    detail=get_error_message("parse_error", req.language)
                )

            # JSON 파싱
            try:
                analysis_result = json.loads(text)
            except json.JSONDecodeError:
                # JSON 추출 시도
                json_match = re.search(r'\{[\s\S]*\}', text)
                if json_match:
                    analysis_result = json.loads(json_match.group())
                else:
                    # 요청 로그 저장 (JSON 파싱 에러)
                    db.save_analysis_log(
                        device_id=req.device_id,
                        language=req.language,
                        tone=req.tone,
                        request_data=req.data,
                        response_data=text,  # raw 응답 저장
                        status_code=500,
                        error_message="JSON parse error"
                    )
                    raise HTTPException(
                        status_code=500,
                        detail=get_error_message("parse_error", req.language)
                    )

            # NSFW 필터링 (출력)
            analysis_result = filter_nsfw_output(analysis_result)

            # #17: 사용량 증가 (성공한 경우에만)
            new_count = db.increment_usage(req.device_id)

            # #13: spendingPlan 필드 기본값 처리
            if "spendingPlan" not in analysis_result:
                analysis_result["spendingPlan"] = ""

            # #17: 남은 분석 횟수 추가
            analysis_result["remainingAnalyses"] = max(0, DAILY_LIMIT - new_count)

            # 요청/응답 로그 저장 (성공)
            db.save_analysis_log(
                device_id=req.device_id,
                language=req.language,
                tone=req.tone,
                request_data=req.data,
                response_data=json.dumps(analysis_result, ensure_ascii=False),
                status_code=200
            )

            # 주기적으로 오래된 데이터 정리
            db.cleanup_old_data()

            return analysis_result

        except httpx.RequestError as e:
            # 요청/응답 로그 저장 (네트워크 에러) - 상세 에러는 로그에만 저장
            db.save_analysis_log(
                device_id=req.device_id,
                language=req.language,
                tone=req.tone,
                request_data=req.data,
                status_code=500,
                error_message=f"Network error: {str(e)}"
            )
            # 사용자에게는 일반화된 메시지만 반환 (보안)
            raise HTTPException(
                status_code=503,  # Service Unavailable
                detail=get_error_message("network_error", req.language, detail="서비스 연결 실패")
            )

# =============================================================================
# 로그 조회 API (관리자 인증 필요)
# =============================================================================
@app.get("/api/logs")
async def get_logs_endpoint(
    limit: int = 50,
    device_id: str = None,
    _: bool = Depends(verify_admin_key)  # 관리자 인증 필수
):
    """분석 요청/응답 로그 조회 (관리자 전용)"""
    logs = db.get_logs(limit=limit, device_id=device_id)
    return {
        "count": len(logs),
        "logs": logs
    }


@app.get("/api/logs/stats")
async def get_logs_stats_endpoint(
    _: bool = Depends(verify_admin_key)  # 관리자 인증 필수
):
    """로그 통계 조회 (관리자 전용)"""
    return db.get_logs_stats()


# =============================================================================
# 서버 실행
# =============================================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3000)
