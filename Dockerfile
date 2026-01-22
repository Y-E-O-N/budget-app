FROM python:3.11-slim

# =============================================================================
# 보안 강화: non-root 사용자 생성
# =============================================================================
# 시스템 사용자 생성 (홈 디렉토리 없음, 로그인 불가)
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/false appuser

WORKDIR /app

# 의존성 설치 (root로 실행)
COPY budget_api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 소스 코드 복사
COPY budget_api/main.py .
COPY budget_api/database.py .

# 데이터 디렉토리 생성 및 권한 설정
RUN mkdir -p /app/data && chown -R appuser:appgroup /app

# =============================================================================
# 보안 강화: non-root 사용자로 전환
# =============================================================================
USER appuser

# 포트 설정 (1024 이상은 non-root도 바인딩 가능)
EXPOSE 8000

# 헬스체크 추가
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# 서버 실행 (non-root 사용자로)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
