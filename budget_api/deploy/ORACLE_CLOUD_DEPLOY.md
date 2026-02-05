# Oracle Cloud Free Tier로 FastAPI 배포하기

## 1. Oracle Cloud 계정 생성 및 VM 인스턴스 생성

### 1.1 계정 생성
1. https://www.oracle.com/cloud/free/ 접속
2. "Start for free" 클릭하여 계정 생성
3. Free Tier 혜택:
   - 2개의 AMD Compute VM (1 OCPU, 1GB RAM 각각)
   - 또는 4개의 Arm-based Ampere A1 cores, 24GB RAM
   - 200GB 블록 스토리지
   - 영구 무료

### 1.2 VM 인스턴스 생성
1. Oracle Cloud Console 접속
2. **Compute > Instances > Create Instance**
3. 설정:
   - **Name**: budget-api-server
   - **Image**: Ubuntu 22.04 (Always Free Eligible)
   - **Shape**: VM.Standard.E2.1.Micro (AMD) 또는 VM.Standard.A1.Flex (ARM)
   - **Networking**: 새 VCN 생성 또는 기존 VCN 선택
   - **SSH Keys**: 새 키 생성 또는 기존 공개키 업로드

### 1.3 네트워크 설정 (Ingress Rules)
1. **Networking > Virtual Cloud Networks > [VCN 선택]**
2. **Security Lists > Default Security List**
3. **Add Ingress Rules**:
   - HTTP (80): `0.0.0.0/0`, TCP, Port 80
   - HTTPS (443): `0.0.0.0/0`, TCP, Port 443
   - (선택) API Port: `0.0.0.0/0`, TCP, Port 3000

## 2. 서버 접속 및 초기 설정

### 2.1 SSH 접속
```bash
ssh -i <private_key_path> ubuntu@<public_ip>
```

### 2.2 시스템 업데이트
```bash
sudo apt update && sudo apt upgrade -y
```

### 2.3 방화벽 설정 (iptables)
Oracle Cloud의 Ubuntu 이미지는 기본적으로 iptables가 설정되어 있습니다.
```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 3000 -j ACCEPT
sudo netfilter-persistent save
```

## 3. Python 및 의존성 설치

```bash
# Python 3.11+ 설치
sudo apt install -y python3 python3-pip python3-venv

# 프로젝트 디렉토리 생성
sudo mkdir -p /opt/budget-api
sudo chown ubuntu:ubuntu /opt/budget-api
cd /opt/budget-api

# 가상환경 생성
python3 -m venv venv
source venv/bin/activate

# 프로젝트 파일 업로드 (로컬에서 실행)
# scp -i <key> -r budget_api/* ubuntu@<ip>:/opt/budget-api/

# 의존성 설치
pip install -r requirements.txt
```

## 4. 환경 변수 설정

```bash
cd /opt/budget-api
cp .env.example .env
nano .env
```

`.env` 파일 수정:
```env
GEMINI_API_KEY=your_actual_gemini_api_key
ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:8080
ADMIN_API_KEY=your_secure_admin_key
IP_RATE_LIMIT_PER_MINUTE=10
# DATABASE_URL=postgresql://... (선택사항, 미설정시 SQLite 사용)
```

## 5. Systemd 서비스 설정

```bash
sudo nano /etc/systemd/system/budget-api.service
```

내용 (`deploy/budget-api.service` 파일 참조):
```ini
[Unit]
Description=Budget API FastAPI Server
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/budget-api
Environment="PATH=/opt/budget-api/venv/bin"
ExecStart=/opt/budget-api/venv/bin/uvicorn main:app --host 127.0.0.1 --port 3000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

서비스 활성화 및 시작:
```bash
sudo systemctl daemon-reload
sudo systemctl enable budget-api
sudo systemctl start budget-api
sudo systemctl status budget-api
```

## 6. Nginx 리버스 프록시 설정

### 6.1 Nginx 설치
```bash
sudo apt install -y nginx
```

### 6.2 설정 파일 생성
```bash
sudo nano /etc/nginx/sites-available/budget-api
```

내용 (`deploy/nginx.conf` 파일 참조):
```nginx
server {
    listen 80;
    server_name your-domain.com;  # 또는 IP 주소

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 120s;
    }
}
```

활성화:
```bash
sudo ln -s /etc/nginx/sites-available/budget-api /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  # 기본 설정 제거
sudo nginx -t  # 설정 테스트
sudo systemctl restart nginx
```

## 7. SSL 인증서 설정 (Let's Encrypt)

### 7.1 도메인이 있는 경우
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 7.2 도메인이 없는 경우 (IP만 사용)
- IP 주소로는 Let's Encrypt SSL 인증서를 발급받을 수 없습니다.
- 무료 도메인 서비스 사용을 권장합니다:
  - https://www.freenom.com (무료 도메인)
  - https://www.duckdns.org (무료 서브도메인)

## 8. Flutter 앱 API URL 업데이트

`lib/constants/app_constants.dart` 파일 수정:
```dart
class AppConstants {
  // Oracle Cloud API URL로 변경
  static const String apiBaseUrl = 'https://your-domain.com';
  // 또는 IP 사용 시 (SSL 없이)
  // static const String apiBaseUrl = 'http://<oracle-cloud-ip>';
}
```

## 9. 배포 확인

### 헬스 체크
```bash
curl http://<server-ip>/health
# 응답: {"status":"ok"}
```

### API 테스트
```bash
curl http://<server-ip>/api/usage/00000000-0000-0000-0000-000000000000
```

## 10. 로그 확인 및 모니터링

```bash
# 서비스 상태 확인
sudo systemctl status budget-api

# 실시간 로그
sudo journalctl -u budget-api -f

# Nginx 로그
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 11. 자동 배포 스크립트

`deploy/setup.sh` 스크립트를 사용하면 위 과정을 자동화할 수 있습니다:
```bash
chmod +x deploy/setup.sh
./deploy/setup.sh
```

## 문제 해결

### 서비스가 시작되지 않는 경우
```bash
sudo journalctl -u budget-api -n 50
```

### 502 Bad Gateway
- Uvicorn이 실행 중인지 확인: `sudo systemctl status budget-api`
- 포트 확인: `sudo ss -tlnp | grep 3000`

### 연결 거부
- iptables 규칙 확인: `sudo iptables -L -n`
- Oracle Cloud Security List 확인
