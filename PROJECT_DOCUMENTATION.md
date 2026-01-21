# 💰 Budget App - 프로젝트 문서

## 📋 프로젝트 개요

**Budget App**은 개인 재무 관리를 위한 크로스플랫폼 모바일 애플리케이션입니다. Flutter로 개발된 클라이언트와 FastAPI 기반의 백엔드 서버로 구성되어 있으며, Google Gemini AI를 활용한 지능형 소비 패턴 분석 기능을 제공합니다.

### 핵심 가치
- **직관적인 예산 관리**: 카테고리별 예산 설정 및 실시간 추적
- **AI 기반 분석**: Gemini AI를 통한 개인화된 소비 패턴 분석 및 조언
- **다국어 지원**: 한국어, 영어, 일본어 완벽 지원
- **데이터 보안**: 로컬 우선 저장 + 클라우드 백업 옵션

---

## 🏗️ 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Client                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Screens   │  │  Providers  │  │  Services   │              │
│  │  (UI Layer) │◄─┤(State Mgmt) │◄─┤ (Business)  │              │
│  └─────────────┘  └─────────────┘  └──────┬──────┘              │
│                                           │                      │
│  ┌─────────────┐  ┌─────────────┐         │                      │
│  │   Models    │  │   Utils     │         │                      │
│  │ (Data Type) │  │ (Helpers)   │         │                      │
│  └─────────────┘  └─────────────┘         │                      │
└───────────────────────────────────────────┼──────────────────────┘
                                            │ HTTP/REST
                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FastAPI Backend (Koyeb)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  main.py    │  │ database.py │  │ Gemini AI   │              │
│  │ (API Layer) │◄─┤(Data Layer) │  │ Integration │              │
│  └─────────────┘  └──────┬──────┘  └─────────────┘              │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              Neon PostgreSQL (AWS Singapore)                     │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │   usage     │  │ analysis_   │                               │
│  │  (Rate Lim) │  │    logs     │                               │
│  └─────────────┘  └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 기술 스택

### Frontend (Flutter)
| 기술 | 버전 | 용도 |
|------|------|------|
| Flutter | 3.x | 크로스플랫폼 UI 프레임워크 |
| Dart | 3.x | 프로그래밍 언어 |
| Provider | 6.1.2 | 상태 관리 |
| Hive | 2.2.3 | 로컬 NoSQL 데이터베이스 |
| FL Chart | 0.69.2 | 차트 시각화 |
| share_plus | 10.0.0 | 이미지/파일 공유 |
| path_provider | 2.1.0 | 파일 시스템 경로 |
| http | 1.2.2 | HTTP 클라이언트 |
| uuid | 4.5.1 | 고유 ID 생성 |
| intl | 0.19.0 | 국제화/날짜 포맷 |

### Backend (FastAPI)
| 기술 | 버전 | 용도 |
|------|------|------|
| FastAPI | 0.109.0 | 웹 프레임워크 |
| Uvicorn | 0.27.0 | ASGI 서버 |
| httpx | 0.26.0 | 비동기 HTTP 클라이언트 |
| Pydantic | 2.5.3 | 데이터 검증 |
| psycopg2-binary | 2.9.9 | PostgreSQL 드라이버 |
| python-dotenv | 1.0.0 | 환경변수 관리 |

### Infrastructure
| 서비스 | 용도 |
|--------|------|
| Koyeb | 백엔드 서버 호스팅 |
| Neon | PostgreSQL 데이터베이스 |
| Google Gemini | AI 분석 API |

---

## 📁 프로젝트 구조

```
budget-app/
├── lib/                          # Flutter 소스 코드
│   ├── main.dart                 # 앱 진입점
│   ├── app_localizations.dart    # 다국어 지원 (ko/en/ja)
│   │
│   ├── models/                   # 데이터 모델
│   │   ├── budget.dart           # 예산 모델
│   │   ├── expense.dart          # 지출 모델
│   │   └── settings.dart         # 설정 모델
│   │
│   ├── providers/                # 상태 관리
│   │   ├── budget_provider.dart  # 예산 상태 관리
│   │   └── settings_provider.dart# 설정 상태 관리
│   │
│   ├── screens/                  # UI 화면
│   │   ├── home_screen.dart      # 메인 탭 컨테이너
│   │   ├── budget_tab.dart       # 예산 관리 탭
│   │   ├── expense_tab.dart      # 지출 관리 탭
│   │   ├── stats_tab.dart        # 통계/분석 탭
│   │   ├── analysis_result_screen.dart  # AI 분석 결과 화면
│   │   └── settings_screen.dart  # 설정 화면
│   │
│   ├── services/                 # 비즈니스 로직
│   │   ├── ai_analysis_service.dart    # AI 분석 API 통신
│   │   ├── database_service.dart       # Hive DB 서비스
│   │   ├── markdown_export_service.dart# 데이터 내보내기
│   │   └── backup_restore_service.dart # 백업/복원
│   │
│   ├── utils/                    # 유틸리티
│   │   ├── result.dart           # Result 타입 (성공/실패)
│   │   └── formatters.dart       # 포맷팅 헬퍼
│   │
│   └── constants/                # 상수
│       └── app_constants.dart    # 앱 상수 정의
│
├── budget_api/                   # FastAPI 백엔드
│   ├── main.py                   # API 엔드포인트 (v2.1.0)
│   ├── database.py               # DB 추상화 레이어
│   └── requirements.txt          # Python 의존성
│
├── Dockerfile                    # Docker 컨테이너 설정
├── pubspec.yaml                  # Flutter 의존성
└── PROJECT_DOCUMENTATION.md      # 이 문서
```

---

## ✨ 주요 기능

### 1. 예산 관리 (Budget Management)
- **카테고리별 예산 설정**: 식비, 교통, 쇼핑 등 맞춤 카테고리
- **고정/변동 지출 구분**: 월세, 보험 등 고정비용 별도 관리
- **예산 소진율 시각화**: 프로그레스 바 및 색상 경고
- **월별 자동 초기화**: 새 달 시작 시 지출 초기화

### 2. 지출 기록 (Expense Tracking)
- **간편한 지출 입력**: 금액, 카테고리, 메모 기록
- **날짜별 조회**: 캘린더 기반 지출 내역 확인
- **수정/삭제**: 기록된 지출 편집 기능
- **카테고리 필터링**: 특정 카테고리만 조회

### 3. 통계 분석 (Statistics)
- **월별 지출 요약**: 총 지출, 카테고리별 비율
- **차트 시각화**: 파이 차트, 바 차트
- **트렌드 분석**: 이전 달 대비 변화율
- **예산 대비 실적**: 남은 예산 실시간 표시

### 4. AI 소비 분석 (AI Analysis)
- **Gemini AI 통합**: Google의 최신 LLM 활용
- **개인화된 조언**: 소비 패턴 기반 맞춤 피드백
- **다국어 분석**: 한국어/영어/일본어 결과 제공
- **이미지 내보내기**: 분석 결과 PNG 저장 및 공유
- **일일 사용 제한**: 디바이스당 3회/일 무료 분석

### 5. 데이터 관리 (Data Management)
- **로컬 저장**: Hive 데이터베이스 (오프라인 지원)
- **JSON 백업**: 데이터 내보내기/가져오기
- **마크다운 내보내기**: 가독성 좋은 텍스트 포맷
- **자동 백업**: 설정에 따른 주기적 백업

### 6. 사용자 경험 (UX)
- **다크 모드**: 시스템 설정 연동
- **다국어 지원**: 한국어, 영어, 일본어
- **통화 설정**: KRW, USD, JPY, EUR 등
- **반응형 UI**: 다양한 화면 크기 지원

---

## 🔧 백엔드 API 명세

### Base URL
```
https://budget-api-xxxxx.koyeb.app
```

### Endpoints

#### 헬스 체크
```http
GET /
Response: {"status": "ok", "version": "2.1.0", "db_type": "postgresql"}
```

#### 사용량 조회
```http
GET /api/usage/{device_id}
Response: {
  "device_id": "xxx",
  "date": "2026-01-21",
  "count": 1,
  "limit": 3,
  "remaining": 2
}
```

#### AI 분석 요청
```http
POST /api/analyze
Body: {
  "device_id": "xxx",
  "data": "markdown_formatted_budget_data",
  "language": "ko",
  "tone": "friendly"
}
Response: {
  "success": true,
  "analysis": "AI 분석 결과...",
  "remaining_today": 2
}
```

#### 로그 조회 (관리자)
```http
GET /api/logs?limit=50
GET /api/logs/stats
```

---

## 📊 데이터베이스 스키마

### usage 테이블
```sql
CREATE TABLE usage (
    id SERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    date TEXT NOT NULL,
    count INTEGER DEFAULT 0,
    UNIQUE(device_id, date)
);
```

### analysis_logs 테이블
```sql
CREATE TABLE analysis_logs (
    id SERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    language TEXT,
    tone TEXT,
    request_data TEXT,
    response_data TEXT,
    status_code INTEGER,
    error_message TEXT,
    created_at TEXT NOT NULL
);
```

---

## 🚀 배포 아키텍처

### 로컬 개발
```bash
# Flutter 앱 실행
flutter run

# 백엔드 로컬 실행
cd budget_api
pip install -r requirements.txt
uvicorn main:app --reload
```

### 프로덕션 배포
1. **백엔드**: GitHub → Koyeb 자동 배포
2. **데이터베이스**: Neon PostgreSQL (DATABASE_URL 환경변수)
3. **클라이언트**: Flutter 빌드 → App Store / Play Store

### 환경변수
```
GEMINI_API_KEY=xxx      # Google Gemini API 키
DATABASE_URL=xxx        # PostgreSQL 연결 문자열 (없으면 SQLite 사용)
```

---

## 📅 개발 이력

### Phase 1: 기본 기능 구현
- Flutter 프로젝트 초기 설정
- 예산/지출 모델 및 Provider 구현
- Hive 데이터베이스 연동
- 기본 UI 화면 구성

### Phase 2: 고급 기능 추가
- AI 분석 기능 (Gemini API 연동)
- 다국어 지원 (한/영/일)
- 차트 시각화 (FL Chart)
- 백업/복원 기능

### Phase 3: 백엔드 고도화 (최신)
- **#26**: AI 분석 결과 전체 화면 표시
- **#27**: PNG 이미지 내보내기 기능
- **#28**: 고정/변동 지출 구분 인식 개선
- **#29**: 분석 전 잔여 횟수 확인 다이얼로그
- **#30**: 상태 배너 위치 조정
- **DB 추상화**: SQLite/PostgreSQL 전환 가능 구조
- **Neon 연동**: 클라우드 PostgreSQL 데이터 영속화

---

## 📈 기술적 성과

### 코드 품질
- **총 코드량**: Flutter ~10,000+ lines, Python ~1,040 lines
- **테스트 커버리지**: 핵심 비즈니스 로직 테스트 완비
- **문서화**: 코드 주석 및 API 문서 제공

### 아키텍처
- **관심사 분리**: Model-Provider-Screen 패턴
- **추상화**: 데이터베이스 인터페이스 패턴 적용
- **확장성**: 새 기능 추가 용이한 모듈 구조

### 성능
- **로컬 우선**: 오프라인 완전 지원
- **효율적 렌더링**: RepaintBoundary 활용
- **최적화된 쿼리**: DB 인덱스 적용

---

## 🔮 향후 계획

1. **기능 확장**
   - 반복 지출 자동 등록
   - 예산 알림 (Push Notification)
   - 가계부 공유 (가족 모드)

2. **기술 개선**
   - 단위 테스트 확대
   - CI/CD 파이프라인 구축
   - 성능 모니터링 도입

3. **플랫폼 확장**
   - 웹 버전 개발
   - 데스크톱 앱 지원

---

## 👤 개발자 정보

이 프로젝트는 개인 학습 및 포트폴리오 목적으로 개발되었습니다.

### 기술 역량 시연
- **모바일 개발**: Flutter/Dart 크로스플랫폼 개발
- **백엔드 개발**: FastAPI REST API 설계 및 구현
- **데이터베이스**: SQLite, PostgreSQL 설계 및 마이그레이션
- **클라우드**: Koyeb, Neon 서비스 활용
- **AI 통합**: LLM API 연동 및 프롬프트 엔지니어링
- **DevOps**: Docker 컨테이너화, 환경변수 관리

---

*문서 최종 업데이트: 2026-01-21*
