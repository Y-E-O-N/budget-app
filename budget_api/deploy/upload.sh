#!/bin/bash
# =============================================================================
# Oracle Cloud 서버로 파일 업로드 Bash 스크립트
# =============================================================================
# 사용법: ./upload.sh -k /path/to/key.pem -s 123.45.67.89
# =============================================================================

set -e

# 기본값
USER="ubuntu"
REMOTE_PATH="/opt/budget-api"

# 인자 파싱
while getopts "k:s:u:p:" opt; do
    case $opt in
        k) PRIVATE_KEY="$OPTARG" ;;
        s) SERVER_IP="$OPTARG" ;;
        u) USER="$OPTARG" ;;
        p) REMOTE_PATH="$OPTARG" ;;
        *) echo "사용법: $0 -k <private_key> -s <server_ip> [-u <user>] [-p <remote_path>]"; exit 1 ;;
    esac
done

if [ -z "$PRIVATE_KEY" ] || [ -z "$SERVER_IP" ]; then
    echo "사용법: $0 -k <private_key> -s <server_ip>"
    echo "예시: $0 -k ~/.ssh/oracle_key.pem -s 123.45.67.89"
    exit 1
fi

echo "=========================================="
echo "Budget API 파일 업로드"
echo "=========================================="

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUDGET_API_DIR="$(dirname "$SCRIPT_DIR")"

echo "소스 디렉토리: $BUDGET_API_DIR"
echo "대상 서버: $USER@$SERVER_IP:$REMOTE_PATH"

# 서버에 디렉토리 생성
echo -e "\n[1/3] 원격 디렉토리 생성..."
ssh -i "$PRIVATE_KEY" "$USER@$SERVER_IP" "sudo mkdir -p $REMOTE_PATH && sudo chown $USER:$USER $REMOTE_PATH"

# 파일 업로드
echo -e "\n[2/3] 파일 업로드..."
FILES=("main.py" "database.py" "requirements.txt" ".env.example")

for FILE in "${FILES[@]}"; do
    LOCAL_PATH="$BUDGET_API_DIR/$FILE"
    if [ -f "$LOCAL_PATH" ]; then
        echo "  업로드: $FILE"
        scp -i "$PRIVATE_KEY" "$LOCAL_PATH" "$USER@$SERVER_IP:$REMOTE_PATH/"
    else
        echo "  건너뜀 (파일 없음): $FILE"
    fi
done

# deploy 폴더 업로드
echo -e "\n[3/3] deploy 폴더 업로드..."
scp -i "$PRIVATE_KEY" -r "$SCRIPT_DIR" "$USER@$SERVER_IP:$REMOTE_PATH/"

echo ""
echo "=========================================="
echo "업로드 완료!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "1. 서버 접속: ssh -i $PRIVATE_KEY $USER@$SERVER_IP"
echo "2. 설치 실행: cd $REMOTE_PATH/deploy && chmod +x setup.sh && ./setup.sh"
echo ""
