# ⚡ Quick Start Guide

빠르게 시작하기 위한 필수 단계만 정리한 가이드입니다.

---

## 🎯 5분 안에 시작하기

### Step 1: Gemini API 키 발급 (2분)

1. https://aistudio.google.com/app/apikey 접속
2. "Create API key" 클릭
3. 생성된 키 복사 (예: `AIzaSy...`)

### Step 2: 환경변수 설정 (1분)

```bash
# budget_api/.env 파일 열기
notepad budget_api\.env

# 아래 내용 수정:
GEMINI_API_KEY=여기에_복사한_키_붙여넣기
```

### Step 3: 관리자 키 생성 (1분)

```bash
# conda 환경 활성화
conda activate budget-app

# 강력한 키 생성
python -c "import secrets; print(secrets.token_hex(32))"

# 출력된 키를 budget_api/.env 파일에 추가:
ADMIN_API_KEY=출력된_키_붙여넣기
```

### Step 4: 서버 실행 (1분)

```bash
cd budget_api
uvicorn main:app --reload
```

브라우저에서 http://localhost:8000/docs 접속 → API 문서 확인!

---

## 📱 Flutter 앱 실행 (5분)

### Step 1: Flutter 패키지 설치

```bash
# 프로젝트 루트로
cd C:\budget-app

# 패키지 다운로드
flutter pub get

# 코드 생성
flutter packages pub run build_runner build
```

### Step 2: 앱 실행

```bash
# 크롬에서 실행
flutter run -d chrome

# 또는 연결된 안드로이드 기기
flutter devices  # 기기 목록 확인
flutter run -d [device_id]
```

---

## ✅ 설정 확인

현재 설정 상태를 자동으로 확인:

```bash
cd budget_api
conda activate budget-app
python check_setup.py
```

**출력 예시**:
```
[OK] GEMINI_API_KEY: AIzaSy...xyz
[OK] ADMIN_API_KEY: 4f8a3c...e0f (strong)
[SUCCESS] Basic setup complete!
```

---

## 🚀 프로덕션 배포 (10분)

### 웹 배포 (GitHub Pages)

```bash
# 코드 푸시하면 자동 배포
git add .
git commit -m "Initial setup"
git push origin main
```

→ https://y-e-o-n.github.io/budget-app/ 에서 확인

### 백엔드 배포 (Koyeb)

1. https://www.koyeb.com/ 가입
2. "Create App" → GitHub 연결
3. 레포지토리: `Y-E-O-N/budget-app`
4. 환경변수 설정:
   ```
   GEMINI_API_KEY=AIzaSy...
   ADMIN_API_KEY=4f8a3c...
   ALLOWED_ORIGINS=https://y-e-o-n.github.io
   ```
5. "Deploy" 클릭

---

## 📚 자세한 가이드

- **전체 설정**: [SETUP_GUIDE.md](./SETUP_GUIDE.md)
- **보안 설정**: [SECURITY_SETUP_GUIDE.md](./SECURITY_SETUP_GUIDE.md)
- **프로젝트 개요**: [README.md](./README.md)

---

## 🆘 문제가 있나요?

### API 키 에러
```
Error: API key not valid
```
→ .env 파일에서 GEMINI_API_KEY 확인, 서버 재시작

### Flutter 실행 안됨
```bash
flutter doctor  # 문제 진단
flutter clean && flutter pub get  # 캐시 초기화
```

### 포트 이미 사용 중
```
Address already in use
```
→ 다른 포트 사용: `uvicorn main:app --port 8001`

---

**더 빠른 시작은 없습니다! 🚀**
