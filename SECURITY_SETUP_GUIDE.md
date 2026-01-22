# 보안 수정 사항 적용 가이드

이 문서는 Budget App의 보안 취약점 수정 사항을 적용하는 방법을 설명합니다.

---

## 목차

1. [사전 요구 사항](#1-사전-요구-사항)
2. [백엔드 (Python/FastAPI) 설정](#2-백엔드-pythonfastapi-설정)
3. [프론트엔드 (Flutter) 설정](#3-프론트엔드-flutter-설정)
4. [Docker 배포](#4-docker-배포)
5. [환경별 설정 가이드](#5-환경별-설정-가이드)
6. [검증 및 테스트](#6-검증-및-테스트)

---

## 1. 사전 요구 사항

### 필요한 도구
- Python 3.11+
- Flutter 3.0+
- Docker (선택사항, 배포 시 필요)

### 변경된 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| `budget_api/main.py` | CORS, 인증, Rate Limiting, NSFW 필터 |
| `budget_api/.env.example` | 환경변수 템플릿 |
| `Dockerfile` | 보안 강화 (non-root user) |
| `pubspec.yaml` | flutter_secure_storage 패키지 추가 |
| `lib/providers/settings_provider.dart` | API 키 암호화 저장 |
| `lib/services/ai_analysis_service.dart` | Device ID 암호화 저장 |
| `lib/services/import_service.dart` | 파일 업로드 검증 |
| `lib/services/secure_storage_service.dart` | 신규 - 암호화 서비스 |

---

## 2. 백엔드 (Python/FastAPI) 설정

### 2.1 환경변수 파일 생성

```bash
cd budget_api

# .env.example을 복사하여 .env 파일 생성
cp .env.example .env
```

### 2.2 .env 파일 설정

`.env` 파일을 편집하여 실제 값을 입력합니다:

```env
# =============================================================================
# 필수 설정
# =============================================================================

# Gemini API 키 (Google AI Studio에서 발급)
GEMINI_API_KEY=AIzaSy...your_actual_key_here

# =============================================================================
# 보안 설정 (프로덕션 필수)
# =============================================================================

# 허용할 도메인 (쉼표로 구분)
# 개발: http://localhost:3000,http://localhost:8080
# 프로덕션: https://yourdomain.com,https://app.yourdomain.com
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# 관리자 API 키 (로그 조회용)
# 강력한 랜덤 문자열 사용 권장 (예: openssl rand -hex 32)
ADMIN_API_KEY=your_secure_admin_key_here

# =============================================================================
# 선택 설정
# =============================================================================

# IP당 분당 최대 요청 수 (기본값: 10)
IP_RATE_LIMIT_PER_MINUTE=10

# PostgreSQL 사용 시 (미설정 시 SQLite 사용)
# DATABASE_URL=postgresql://user:password@host:5432/dbname
```

### 2.3 관리자 API 키 생성 방법

```bash
# Linux/macOS
openssl rand -hex 32

# Windows PowerShell
[System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()

# Python
python -c "import secrets; print(secrets.token_hex(32))"
```

### 2.4 서버 실행 (개발 환경)

```bash
cd budget_api

# 가상환경 생성 및 활성화
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/macOS
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
uvicorn main:app --reload --port 8000
```

### 2.5 API 테스트

```bash
# 헬스 체크
curl http://localhost:8000/health

# 예상 응답: {"status":"ok"}
```

---

## 3. 프론트엔드 (Flutter) 설정

### 3.1 패키지 설치

```bash
cd budget-app

# pubspec.yaml의 새 패키지 설치
flutter pub get
```

### 3.2 Android 설정

`android/app/build.gradle` 파일에서 minSdkVersion 확인:

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // flutter_secure_storage는 23 이상 필요
    }
}
```

### 3.3 iOS 설정

`ios/Runner/Info.plist`에 Keychain 접근 설정 확인:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.yourcompany.budgetapp</string>
</array>
```

### 3.4 기존 데이터 마이그레이션

앱 업데이트 시 기존 사용자의 데이터는 자동으로 마이그레이션됩니다:

1. **API 키**: Hive(평문) → flutter_secure_storage(암호화)
2. **Device ID**: Hive(평문) → flutter_secure_storage(암호화)

마이그레이션 코드는 이미 포함되어 있으며, 앱 시작 시 자동 실행됩니다:
- `settings_provider.dart` - `_migrateApiKeyToSecureStorage()`
- `ai_analysis_service.dart` - `getDeviceId()` 내부 마이그레이션 로직

### 3.5 앱 빌드

```bash
# Android APK 빌드
flutter build apk --release

# Android App Bundle (Play Store용)
flutter build appbundle --release

# iOS 빌드
flutter build ios --release
```

---

## 4. Docker 배포

### 4.1 Docker 이미지 빌드

```bash
cd budget-app

# 이미지 빌드
docker build -t budget-api:latest .
```

### 4.2 Docker 컨테이너 실행

```bash
# .env 파일 사용
docker run -d \
  --name budget-api \
  -p 8000:8000 \
  --env-file budget_api/.env \
  --restart unless-stopped \
  budget-api:latest
```

### 4.3 Docker Compose 설정 (선택)

`docker-compose.yml` 파일 생성:

```yaml
version: '3.8'

services:
  api:
    build: .
    container_name: budget-api
    ports:
      - "8000:8000"
    env_file:
      - budget_api/.env
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    # 선택: 데이터 영속성
    volumes:
      - ./data:/app/data
```

실행:

```bash
docker-compose up -d
```

### 4.4 컨테이너 상태 확인

```bash
# 실행 상태 확인
docker ps

# 로그 확인
docker logs budget-api

# 헬스체크 상태 확인
docker inspect --format='{{.State.Health.Status}}' budget-api
```

---

## 5. 환경별 설정 가이드

### 5.1 개발 환경

```env
# budget_api/.env (개발용)
GEMINI_API_KEY=your_dev_api_key
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000
ADMIN_API_KEY=dev_admin_key_12345
IP_RATE_LIMIT_PER_MINUTE=100
```

### 5.2 스테이징 환경

```env
# budget_api/.env (스테이징용)
GEMINI_API_KEY=your_staging_api_key
ALLOWED_ORIGINS=https://staging.yourdomain.com
ADMIN_API_KEY=staging_secure_key_here
IP_RATE_LIMIT_PER_MINUTE=20
```

### 5.3 프로덕션 환경

```env
# budget_api/.env (프로덕션용)
GEMINI_API_KEY=your_production_api_key
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
ADMIN_API_KEY=production_very_secure_key_generated_by_openssl
IP_RATE_LIMIT_PER_MINUTE=10
DATABASE_URL=postgresql://user:password@db.yourdomain.com:5432/budget_db
```

### 5.4 Nginx 리버스 프록시 설정 (프로덕션 권장)

```nginx
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Rate Limiting (Nginx 레벨)
        limit_req zone=api burst=20 nodelay;
    }
}

# Rate Limiting 설정
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
```

---

## 6. 검증 및 테스트

### 6.1 CORS 설정 테스트

```bash
# 허용된 도메인에서 요청
curl -H "Origin: http://localhost:3000" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS \
     http://localhost:8000/api/analyze

# 허용되지 않은 도메인에서 요청 (차단되어야 함)
curl -H "Origin: http://malicious-site.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS \
     http://localhost:8000/api/analyze
```

### 6.2 관리자 인증 테스트

```bash
# 인증 없이 로그 조회 (401 에러 예상)
curl http://localhost:8000/api/logs

# 인증 헤더 포함 (성공 예상)
curl -H "X-Admin-Key: your_admin_api_key" \
     http://localhost:8000/api/logs
```

### 6.3 Rate Limiting 테스트

```bash
# 분당 제한 테스트 (11번째 요청부터 429 에러 예상)
for i in {1..15}; do
  echo "Request $i:"
  curl -s -o /dev/null -w "%{http_code}\n" \
       -X POST http://localhost:8000/api/analyze \
       -H "Content-Type: application/json" \
       -d '{"data":"test","device_id":"550e8400-e29b-41d4-a716-446655440000"}'
  sleep 0.5
done
```

### 6.4 Device ID 검증 테스트

```bash
# 유효한 UUID (성공 예상)
curl -X POST http://localhost:8000/api/analyze \
     -H "Content-Type: application/json" \
     -d '{"data":"test","device_id":"550e8400-e29b-41d4-a716-446655440000"}'

# 잘못된 형식 (400 에러 예상)
curl -X POST http://localhost:8000/api/analyze \
     -H "Content-Type: application/json" \
     -d '{"data":"test","device_id":"invalid-device-id"}'
```

### 6.5 Flutter 앱 테스트

```bash
# 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/security_test.dart
```

---

## 7. 문제 해결

### 7.1 CORS 오류

**증상**: 브라우저 콘솔에 CORS 오류 표시

**해결**:
1. `ALLOWED_ORIGINS` 환경변수에 클라이언트 도메인이 포함되어 있는지 확인
2. 프로토콜(http/https) 포함 여부 확인
3. 포트 번호 포함 여부 확인

```env
# 올바른 예
ALLOWED_ORIGINS=http://localhost:3000,https://myapp.com

# 잘못된 예 (프로토콜 누락)
ALLOWED_ORIGINS=localhost:3000,myapp.com
```

### 7.2 flutter_secure_storage 오류

**증상**: Android에서 "Unhandled Exception: PlatformException"

**해결**:
1. `minSdkVersion`이 23 이상인지 확인
2. 앱 재설치 (기존 Keystore 충돌 시)

```bash
flutter clean
flutter pub get
flutter run
```

### 7.3 Rate Limiting 과도한 차단

**증상**: 정상 사용자도 429 오류 발생

**해결**:
1. `IP_RATE_LIMIT_PER_MINUTE` 값 증가
2. 프록시 뒤에서 실행 시 `X-Forwarded-For` 헤더 전달 확인

### 7.4 Docker 권한 오류

**증상**: 컨테이너 시작 시 권한 오류

**해결**:
```bash
# 데이터 디렉토리 권한 설정
sudo chown -R 1000:1000 ./data
```

---

## 8. 보안 체크리스트

배포 전 확인 사항:

- [ ] `GEMINI_API_KEY` 설정 완료
- [ ] `ALLOWED_ORIGINS`에 프로덕션 도메인만 포함
- [ ] `ADMIN_API_KEY`를 강력한 랜덤 문자열로 설정
- [ ] HTTPS 적용 (프로덕션)
- [ ] `.env` 파일이 `.gitignore`에 포함되어 있는지 확인
- [ ] Docker 컨테이너가 non-root 사용자로 실행되는지 확인
- [ ] 로그에 민감 정보가 노출되지 않는지 확인
- [ ] Rate Limiting이 정상 작동하는지 테스트

---

## 9. 참고 자료

- [FastAPI 보안 가이드](https://fastapi.tiangolo.com/tutorial/security/)
- [Flutter Secure Storage 문서](https://pub.dev/packages/flutter_secure_storage)
- [Docker 보안 모범 사례](https://docs.docker.com/develop/security-best-practices/)
- [OWASP API Security Top 10](https://owasp.org/API-Security/)
