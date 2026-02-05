#!/bin/bash
# =============================================================================
# Oracle Cloud FastAPI 배포 스크립트
# =============================================================================
# 사용법: chmod +x setup.sh && ./setup.sh
# =============================================================================

set -e  # 에러 발생 시 즉시 중단

echo "=========================================="
echo "Budget API 서버 배포 스크립트"
echo "=========================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 변수 설정
APP_DIR="/opt/budget-api"
SERVICE_NAME="budget-api"
PYTHON_VERSION="python3"

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}참고: 일부 명령은 sudo 권한이 필요합니다.${NC}"
fi

# 1. 시스템 업데이트
echo -e "\n${GREEN}[1/8] 시스템 업데이트...${NC}"
sudo apt update && sudo apt upgrade -y

# 2. 필수 패키지 설치
echo -e "\n${GREEN}[2/8] 필수 패키지 설치...${NC}"
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx

# 3. 프로젝트 디렉토리 설정
echo -e "\n${GREEN}[3/8] 프로젝트 디렉토리 설정...${NC}"
if [ ! -d "$APP_DIR" ]; then
    sudo mkdir -p $APP_DIR
    sudo chown $USER:$USER $APP_DIR
fi

# 현재 스크립트 디렉토리에서 파일 복사 (budget_api 폴더 내에서 실행 가정)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

echo "소스 디렉토리: $PARENT_DIR"
cp -r "$PARENT_DIR"/*.py $APP_DIR/ 2>/dev/null || true
cp -r "$PARENT_DIR"/requirements.txt $APP_DIR/ 2>/dev/null || true
cp -r "$PARENT_DIR"/.env.example $APP_DIR/ 2>/dev/null || true

# 4. Python 가상환경 설정
echo -e "\n${GREEN}[4/8] Python 가상환경 설정...${NC}"
cd $APP_DIR
$PYTHON_VERSION -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 5. 환경 변수 설정
echo -e "\n${GREEN}[5/8] 환경 변수 설정...${NC}"
if [ ! -f "$APP_DIR/.env" ]; then
    cp $APP_DIR/.env.example $APP_DIR/.env
    echo -e "${YELLOW}⚠️  .env 파일을 수정해주세요: nano $APP_DIR/.env${NC}"
    echo -e "${YELLOW}   - GEMINI_API_KEY 설정 필수${NC}"
    echo -e "${YELLOW}   - ALLOWED_ORIGINS 설정 권장${NC}"
else
    echo ".env 파일이 이미 존재합니다."
fi

# 6. Systemd 서비스 설정
echo -e "\n${GREEN}[6/8] Systemd 서비스 설정...${NC}"
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Budget API FastAPI Server
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/uvicorn main:app --host 127.0.0.1 --port 3000
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# 7. Nginx 설정
echo -e "\n${GREEN}[7/8] Nginx 설정...${NC}"
read -p "도메인 또는 IP 주소 입력 (예: example.com 또는 123.45.67.89): " DOMAIN

sudo tee /etc/nginx/sites-available/$SERVICE_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 120s;
        proxy_connect_timeout 120s;
    }
}
EOF

# 기존 설정 제거 및 새 설정 활성화
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/

# Nginx 설정 테스트
if sudo nginx -t; then
    sudo systemctl restart nginx
else
    echo -e "${RED}Nginx 설정 오류!${NC}"
    exit 1
fi

# 8. 방화벽 설정 (Oracle Cloud iptables)
echo -e "\n${GREEN}[8/8] 방화벽 설정...${NC}"
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || true

# 서비스 시작
echo -e "\n${GREEN}서비스 시작...${NC}"
sudo systemctl start $SERVICE_NAME

# 완료 메시지
echo ""
echo "=========================================="
echo -e "${GREEN}배포 완료!${NC}"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "1. .env 파일 수정: nano $APP_DIR/.env"
echo "2. 서비스 재시작: sudo systemctl restart $SERVICE_NAME"
echo "3. (선택) SSL 설정: sudo certbot --nginx -d $DOMAIN"
echo ""
echo "상태 확인:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  curl http://$DOMAIN/health"
echo ""
echo "로그 확인:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
