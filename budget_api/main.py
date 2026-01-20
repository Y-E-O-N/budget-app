# =============================================================================
# main.py - Budget App AI Analysis Proxy Server (FastAPI)
# =============================================================================
# #17: device_id 기반 일일 3회 제한
# #13: 잔여 기간 지출 계획 조언 추가
# =============================================================================
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import httpx
import os
import re
import json
import sqlite3
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

app = FastAPI(title="Budget AI API", version="2.0.0")

# CORS 설정 (Flutter 웹에서 호출 가능하도록)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Gemini API 설정
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = "gemini-2.5-flash-lite-preview-09-2025"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

# #17: 일일 분석 횟수 제한
DAILY_LIMIT = 3
KST = ZoneInfo("Asia/Seoul")

# =============================================================================
# #17: SQLite 데이터베이스 설정 (분석 횟수 추적)
# =============================================================================
DB_PATH = os.path.join(os.path.dirname(__file__), "usage.db")

def init_db():
    """데이터베이스 초기화"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # device_id별 일일 사용량 추적 테이블
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            date TEXT NOT NULL,
            count INTEGER DEFAULT 0,
            UNIQUE(device_id, date)
        )
    """)
    # 분석 요청/응답 로그 테이블
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS analysis_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            language TEXT,
            tone TEXT,
            request_data TEXT,
            response_data TEXT,
            status_code INTEGER,
            error_message TEXT,
            created_at TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()


def save_analysis_log(
    device_id: str,
    language: str,
    tone: str,
    request_data: str,
    response_data: str = None,
    status_code: int = 200,
    error_message: str = None
):
    """분석 요청/응답 로그 저장"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    created_at = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S")
    cursor.execute("""
        INSERT INTO analysis_logs
        (device_id, language, tone, request_data, response_data, status_code, error_message, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (device_id, language, tone, request_data, response_data, status_code, error_message, created_at))
    conn.commit()
    conn.close()

def get_today_kst() -> str:
    """KST 기준 오늘 날짜 반환 (YYYY-MM-DD)"""
    return datetime.now(KST).strftime("%Y-%m-%d")

def get_usage_count(device_id: str) -> int:
    """오늘의 사용 횟수 조회"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    today = get_today_kst()
    cursor.execute("SELECT count FROM usage WHERE device_id = ? AND date = ?", (device_id, today))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 0

def increment_usage(device_id: str) -> int:
    """사용 횟수 증가 및 현재 횟수 반환"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    today = get_today_kst()
    # UPSERT: 있으면 증가, 없으면 삽입
    cursor.execute("""
        INSERT INTO usage (device_id, date, count) VALUES (?, ?, 1)
        ON CONFLICT(device_id, date) DO UPDATE SET count = count + 1
    """, (device_id, today))
    conn.commit()
    # 현재 횟수 조회
    cursor.execute("SELECT count FROM usage WHERE device_id = ? AND date = ?", (device_id, today))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 1

def cleanup_old_data():
    """7일 이상 된 데이터 정리"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cutoff = (datetime.now(KST) - timedelta(days=7)).strftime("%Y-%m-%d")
    cursor.execute("DELETE FROM usage WHERE date < ?", (cutoff,))
    conn.commit()
    conn.close()

# 서버 시작 시 DB 초기화
init_db()

# =============================================================================
# NSFW 필터 설정
# =============================================================================
NSFW_KEYWORDS = [
    # 욕설/비속어 (한국어)
    "시발", "씨발", "병신", "지랄", "새끼", "개새끼", "미친", "존나", "좆",
    # 욕설/비속어 (영어)
    "fuck", "shit", "bitch", "asshole", "bastard", "damn",
    # 욕설/비속어 (일본어)
    "くそ", "ちくしょう", "馬鹿",
]

def filter_nsfw_input(text: str) -> str:
    """입력 텍스트에서 NSFW 콘텐츠 필터링"""
    filtered = text
    for keyword in NSFW_KEYWORDS:
        pattern = re.compile(re.escape(keyword), re.IGNORECASE)
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
# 요청/응답 모델
# =============================================================================
class AnalyzeRequest(BaseModel):
    data: str
    language: str = "ko"
    tone: str = "gentle"  # gentle, praise, factual, coach, humorous
    device_id: str  # #17: 기기 고유 식별자 (필수)

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
    return {"status": "ok", "api_key_configured": bool(GEMINI_API_KEY)}

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
    count = get_usage_count(device_id)
    return UsageResponse(
        device_id=device_id,
        date=get_today_kst(),
        count=count,
        limit=DAILY_LIMIT,
        remaining=max(0, DAILY_LIMIT - count)
    )

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest):
    """AI 가계부 분석 (#17: 일일 3회 제한 적용)"""

    # #17: device_id 필수 확인
    if not req.device_id or req.device_id.strip() == "":
        raise HTTPException(
            status_code=400,
            detail=get_error_message("device_id_required", req.language)
        )

    # #17: 일일 사용량 확인
    current_count = get_usage_count(req.device_id)
    if current_count >= DAILY_LIMIT:
        # 요청 로그 저장 (Rate Limit)
        save_analysis_log(
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
                f"{GEMINI_URL}?key={GEMINI_API_KEY}",
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
                detail = error_data.get("error", {}).get("message", "Gemini API error")
                # 요청 로그 저장 (Gemini API 에러)
                save_analysis_log(
                    device_id=req.device_id,
                    language=req.language,
                    tone=req.tone,
                    request_data=req.data,
                    status_code=response.status_code,
                    error_message=f"Gemini API error: {detail}"
                )
                raise HTTPException(
                    status_code=response.status_code,
                    detail=get_error_message("gemini_error", req.language, detail=detail)
                )

            result = response.json()
            text = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")

            if not text:
                # 요청 로그 저장 (빈 응답)
                save_analysis_log(
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
                    save_analysis_log(
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
            new_count = increment_usage(req.device_id)

            # #13: spendingPlan 필드 기본값 처리
            if "spendingPlan" not in analysis_result:
                analysis_result["spendingPlan"] = ""

            # #17: 남은 분석 횟수 추가
            analysis_result["remainingAnalyses"] = max(0, DAILY_LIMIT - new_count)

            # 요청/응답 로그 저장 (성공)
            save_analysis_log(
                device_id=req.device_id,
                language=req.language,
                tone=req.tone,
                request_data=req.data,
                response_data=json.dumps(analysis_result, ensure_ascii=False),
                status_code=200
            )

            # 주기적으로 오래된 데이터 정리
            cleanup_old_data()

            return analysis_result

        except httpx.RequestError as e:
            # 요청/응답 로그 저장 (네트워크 에러)
            save_analysis_log(
                device_id=req.device_id,
                language=req.language,
                tone=req.tone,
                request_data=req.data,
                status_code=500,
                error_message=str(e)
            )
            raise HTTPException(
                status_code=500,
                detail=get_error_message("network_error", req.language, detail=str(e))
            )

# =============================================================================
# 로그 조회 API
# =============================================================================
@app.get("/api/logs")
async def get_logs(limit: int = 50, device_id: str = None):
    """분석 요청/응답 로그 조회"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # dict처럼 접근 가능하게
    cursor = conn.cursor()

    if device_id:
        cursor.execute("""
            SELECT * FROM analysis_logs
            WHERE device_id = ?
            ORDER BY created_at DESC
            LIMIT ?
        """, (device_id, limit))
    else:
        cursor.execute("""
            SELECT * FROM analysis_logs
            ORDER BY created_at DESC
            LIMIT ?
        """, (limit,))

    rows = cursor.fetchall()
    conn.close()

    return {
        "count": len(rows),
        "logs": [dict(row) for row in rows]
    }


@app.get("/api/logs/stats")
async def get_logs_stats():
    """로그 통계 조회"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 전체 요청 수
    cursor.execute("SELECT COUNT(*) FROM analysis_logs")
    total = cursor.fetchone()[0]

    # 성공/실패 통계
    cursor.execute("SELECT COUNT(*) FROM analysis_logs WHERE status_code = 200")
    success = cursor.fetchone()[0]

    # 기기별 요청 수
    cursor.execute("""
        SELECT device_id, COUNT(*) as count
        FROM analysis_logs
        GROUP BY device_id
        ORDER BY count DESC
    """)
    by_device = cursor.fetchall()

    # 날짜별 요청 수
    cursor.execute("""
        SELECT DATE(created_at) as date, COUNT(*) as count
        FROM analysis_logs
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        LIMIT 7
    """)
    by_date = cursor.fetchall()

    conn.close()

    return {
        "total_requests": total,
        "success_count": success,
        "error_count": total - success,
        "by_device": [{"device_id": d[0], "count": d[1]} for d in by_device],
        "by_date": [{"date": d[0], "count": d[1]} for d in by_date]
    }


# =============================================================================
# 서버 실행
# =============================================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3000)
