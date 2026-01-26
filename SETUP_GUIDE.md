# Budget App 세팅 가이드

이 가이드는 Budget App의 필수 설정을 완료하는 방법을 안내합니다.

---

## 📋 목차

1. [필수 세팅](#1-필수-세팅)
   - [1.1 Gemini API 키 발급](#11-gemini-api-키-발급)
   - [1.2 관리자 API 키 생성](#12-관리자-api-키-생성)
   - [1.3 백엔드 환경변수 설정](#13-백엔드-환경변수-설정)
   - [1.4 Flutter 패키지 설치](#14-flutter-패키지-설치)

2. [GitHub 자동 배포 세팅](#2-github-자동-배포-세팅)
   - [2.1 GitHub Pages 활성화](#21-github-pages-활성화)
   - [2.2 iOS 빌드용 Secrets (선택)](#22-ios-빌드용-secrets-선택)

3. [백엔드 배포 세팅](#3-백엔드-배포-세팅)
   - [3.1 Koyeb/Fly.io/Railway 배포](#31-koyebflyiorailway-배포)
   - [3.2 프로덕션 CORS 설정](#32-프로덕션-cors-설정)

4. [검증](#4-검증)

---

## 1. 필수 세팅

### 1.1 Gemini API 키 발급

Budget App의 AI 분석 기능에 필요한 Google Gemini API 키를 발급받습니다.

**단계**:

1. **Google AI Studio 접속**
   - 브라우저에서 https://aistudio.google.com/app/apikey 접속

2. **API 키 생성**
   - "Create API key" 버튼 클릭
   - Google 계정으로 로그인 (필요시)
   - "Create API key in new project" 클릭

3. **API 키 복사**
   - 생성된 키를 안전한 곳에 복사 (예: `AIzaSy...`)
   - ⚠️ 이 키는 다시 확인할 수 없으므로 반드시 저장!

**비용**:
- Gemini API는 무료 티어 제공 (일일 제한 있음)
- 자세한 요금: https://ai.google.dev/pricing

---

### 1.2 관리자 API 키 생성

로그 조회 등 관리 기능 접근을 위한 강력한 API 키를 생성합니다.

**방법 1: Python 사용**
```bash
conda activate budget-app
python -c "import secrets; print(secrets.token_hex(32))"
```

**방법 2: PowerShell 사용**
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

**방법 3: 온라인 생성기**
- https://randomkeygen.com/ 접속
- "256-bit WPA Key" 또는 "CodeIgniter Encryption Keys" 항목 복사

**예시 출력**:
```
4f8a3c2e1d9b7e6f5a4c3b2d1e9f8a7b6c5d4e3f2a1b9c8d7e6f5a4b3c2d1e0f
```

---

### 1.3 백엔드 환경변수 설정

발급받은 키들을 `.env` 파일에 설정합니다.

**단계**:

1. **기존 .env 파일 확인**
   ```bash
   # budget_api/.env 파일 열기
   code budget_api/.env
   # 또는
   notepad budget_api/.env
   ```

2. **실제 값으로 업데이트**
   ```env
   # Gemini API 키 (1.1에서 발급받은 키)
   GEMINI_API_KEY=AIzaSy...your_actual_key_here

   # 관리자 API 키 (1.2에서 생성한 키)
   ADMIN_API_KEY=4f8a3c2e1d9b7e6f5a4c3b2d1e9f8a7b6c5d4e3f2a1b9c8d7e6f5a4b3c2d1e0f

   # CORS 설정 (개발 환경은 기본값 사용, 프로덕션은 3.2 참조)
   # ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

   # Rate Limiting (기본값 사용)
   IP_RATE_LIMIT_PER_MINUTE=10
   ```

3. **저장 후 서버 재시작**
   ```bash
   cd budget_api
   conda activate budget-app
   uvicorn main:app --reload
   ```

4. **확인**
   - 브라우저에서 http://localhost:8000/docs 접속
   - API 문서가 보이면 성공!

---

### 1.4 Flutter 패키지 설치

Flutter 앱의 보안 저장소 등 필요한 패키지를 설치합니다.

**사전 확인**: Flutter가 설치되어 있어야 합니다.
```bash
flutter --version
```

**Flutter 미설치 시**:
- Windows: https://docs.flutter.dev/get-started/install/windows
- 또는 간단히: `winget install Google.Flutter`

**패키지 설치**:
```bash
# 프로젝트 루트로 이동
cd C:\budget-app

# Flutter 패키지 다운로드
flutter pub get

# 코드 생성 (Hive 어댑터)
flutter packages pub run build_runner build
```

**확인**:
```bash
# 앱 실행 (크롬)
flutter run -d chrome

# 또는 연결된 안드로이드 기기
flutter run
```

---

## 2. GitHub 자동 배포 세팅

### 2.1 GitHub Pages 활성화

Flutter 웹 앱을 GitHub Pages에 자동 배포합니다.

**단계**:

1. **GitHub 레포지토리 접속**
   - https://github.com/Y-E-O-N/budget-app 접속

2. **Settings → Pages 이동**
   - 레포지토리 상단 "Settings" 클릭
   - 왼쪽 메뉴에서 "Pages" 클릭

3. **Source 설정**
   - Source: "GitHub Actions" 선택
   - (기존 "Deploy from a branch"에서 변경)

4. **배포 확인**
   ```bash
   git add .
   git commit -m "Enable GitHub Pages"
   git push origin main
   ```
   - GitHub Actions 탭에서 워크플로우 실행 확인
   - 완료 후 https://y-e-o-n.github.io/budget-app/ 접속

**예상 URL**: `https://y-e-o-n.github.io/budget-app/`

---

### 2.2 iOS 빌드용 Secrets (선택)

실제 iOS 기기용 IPA 파일을 빌드하려면 Apple 인증서가 필요합니다.

**⚠️ 주의**: Apple Developer 계정 필요 (연 $99)

**필요한 Secrets**:
1. `P12_CERTIFICATE_BASE64`: iOS 인증서 (base64 인코딩)
2. `P12_PASSWORD`: 인증서 비밀번호
3. `PROVISION_PROFILE_BASE64`: 프로비저닝 프로파일 (base64)
4. `KEYCHAIN_PASSWORD`: 임시 키체인 비밀번호 (랜덤 문자열)

**설정 방법**:
1. GitHub 레포지토리 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. 위 4개 항목 추가

**인증서 준비**:
```bash
# .p12 파일을 base64로 인코딩
base64 -i certificate.p12 -o certificate_base64.txt

# 프로비저닝 프로파일 인코딩
base64 -i profile.mobileprovision -o profile_base64.txt
```

**또는 시뮬레이터용만 사용**:
- Secrets 설정 없이도 자동으로 시뮬레이터용 빌드는 생성됨
- GitHub Actions → Artifacts에서 다운로드 가능

---

## 3. 백엔드 배포 세팅

### 3.1 Koyeb/Fly.io/Railway 배포

FastAPI 백엔드를 클라우드에 배포합니다.

#### 옵션 A: Koyeb (추천)

**이유**: Dockerfile 있음, 무료 티어, 자동 배포

**단계**:

1. **Koyeb 가입**
   - https://www.koyeb.com/ 접속
   - GitHub 계정으로 로그인

2. **새 앱 생성**
   - "Create App" 클릭
   - "GitHub" 선택
   - `Y-E-O-N/budget-app` 레포지토리 연결

3. **빌드 설정**
   - Builder: "Dockerfile"
   - Dockerfile path: `/Dockerfile`
   - Port: `8000`

4. **환경변수 설정**
   - Environment variables 섹션에서:
   ```
   GEMINI_API_KEY=AIzaSy...
   ADMIN_API_KEY=4f8a3c2e...
   ALLOWED_ORIGINS=https://y-e-o-n.github.io
   IP_RATE_LIMIT_PER_MINUTE=10
   ```

5. **배포**
   - "Deploy" 클릭
   - 배포 완료 후 URL 확인 (예: `https://your-app.koyeb.app`)

#### 옵션 B: Fly.io

```bash
# Fly CLI 설치
curl -L https://fly.io/install.sh | sh

# 로그인
fly auth login

# 앱 생성 및 배포
fly launch
fly secrets set GEMINI_API_KEY=AIzaSy...
fly secrets set ADMIN_API_KEY=4f8a3c2e...
fly secrets set ALLOWED_ORIGINS=https://y-e-o-n.github.io
fly deploy
```

#### 옵션 C: Railway

1. https://railway.app/ 접속
2. "New Project" → "Deploy from GitHub repo"
3. `budget-app` 선택
4. 환경변수 설정 (위와 동일)
5. 자동 배포 완료

---

### 3.2 프로덕션 CORS 설정

백엔드 배포 후 프론트엔드에서 접근할 수 있도록 CORS를 설정합니다.

**상황**:
- 프론트엔드: `https://y-e-o-n.github.io/budget-app/`
- 백엔드: `https://your-app.koyeb.app`

**백엔드 .env 업데이트** (클라우드 플랫폼 환경변수):
```env
ALLOWED_ORIGINS=https://y-e-o-n.github.io,http://localhost:3000
```

**Flutter 앱에서 API URL 설정**:

1. `lib/services/ai_analysis_service.dart` 파일 열기
2. API URL을 배포된 백엔드 주소로 변경:
   ```dart
   // 기존
   static const String apiUrl = 'http://localhost:8000';

   // 변경 후
   static const String apiUrl = 'https://your-app.koyeb.app';
   ```

3. 커밋 및 푸시:
   ```bash
   git add .
   git commit -m "Update API URL to production"
   git push origin main
   ```

---

## 4. 검증

모든 설정이 완료되었는지 확인합니다.

### ✅ 체크리스트

**로컬 개발 환경**:
- [ ] Gemini API 키 발급 완료
- [ ] `budget_api/.env` 파일에 실제 키 설정
- [ ] `uvicorn main:app --reload` 실행 → http://localhost:8000/docs 접속 성공
- [ ] `flutter pub get` 실행 성공
- [ ] `flutter run` 앱 실행 성공

**GitHub 배포**:
- [ ] GitHub Pages 활성화
- [ ] `git push origin main` 후 Actions 성공
- [ ] https://y-e-o-n.github.io/budget-app/ 접속 성공

**백엔드 배포** (선택):
- [ ] Koyeb/Fly.io/Railway에 배포 완료
- [ ] 환경변수 설정 완료 (GEMINI_API_KEY, ADMIN_API_KEY, ALLOWED_ORIGINS)
- [ ] Flutter 앱에서 API URL 업데이트
- [ ] AI 분석 기능 테스트 성공

### 🧪 기능 테스트

**로컬 API 테스트**:
```bash
cd budget_api
conda activate budget-app
python test_api.py
python test_security.py
```

**Health Check**:
```bash
# 로컬
curl http://localhost:8000/health

# 프로덕션
curl https://your-app.koyeb.app/health
```

**AI 분석 테스트** (Flutter 앱에서):
1. 예산 생성
2. 지출 내역 추가
3. AI 분석 버튼 클릭
4. 분석 결과 확인

---

## 🆘 문제 해결

### Gemini API 에러
```
Error: API key not valid
```
**해결**:
1. .env 파일의 GEMINI_API_KEY 확인
2. Google AI Studio에서 키 재확인
3. 서버 재시작

### CORS 에러
```
Access to fetch at 'https://api.example.com' has been blocked by CORS policy
```
**해결**:
1. 백엔드 환경변수에 ALLOWED_ORIGINS 설정 확인
2. 프론트엔드 도메인이 정확히 일치하는지 확인 (http vs https, 끝에 슬래시 주의)

### Flutter 패키지 설치 실패
```
Error: Cannot run with sound null safety
```
**해결**:
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Rate Limit 초과
```
429 Too Many Requests
```
**해결**:
- IP_RATE_LIMIT_PER_MINUTE 값 증가
- 또는 잠시 대기 후 재시도

---

## 📚 추가 참고자료

- [SECURITY_SETUP_GUIDE.md](./SECURITY_SETUP_GUIDE.md) - 상세 보안 설정
- [budget_api/SECURITY_TEST_REPORT.md](./budget_api/SECURITY_TEST_REPORT.md) - 보안 테스트 결과
- [README.md](./README.md) - 프로젝트 개요
- [Google Gemini API Docs](https://ai.google.dev/docs)
- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Flutter Docs](https://docs.flutter.dev/)

---

## 💡 다음 단계

설정이 완료되면:
1. 실제 예산 데이터 입력하여 테스트
2. AI 분석 기능 활용
3. 모바일 앱 빌드 (Android/iOS)
4. 사용자 피드백 수집 및 개선

**Happy Budgeting! 💰**
