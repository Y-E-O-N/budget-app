#!/usr/bin/env python
"""FastAPI 서버 테스트 스크립트"""
import sys
sys.path.insert(0, '.')

from main import app

print("=== FastAPI App Initialization Test ===")
print(f"[OK] App title: {app.title}")
print(f"[OK] App version: {app.version}")

# 라우트 확인
routes = [route.path for route in app.routes]
print(f"\n[OK] Available routes: {len(routes)}")
for route in routes:
    if hasattr(route, '__name__'):
        continue  # 메타데이터 라우트 제외
    print(f"  - {route}")

# 환경변수 확인
import os
print("\n=== Environment Variables ===")
print(f"[OK] GEMINI_API_KEY: {'SET' if os.getenv('GEMINI_API_KEY') else 'NOT SET'}")
print(f"[OK] ADMIN_API_KEY: {'SET' if os.getenv('ADMIN_API_KEY') else 'NOT SET'}")
print(f"[OK] ALLOWED_ORIGINS: {os.getenv('ALLOWED_ORIGINS', 'NOT SET (using localhost)')}")
print(f"[OK] IP_RATE_LIMIT_PER_MINUTE: {os.getenv('IP_RATE_LIMIT_PER_MINUTE', '10 (default)')}")

print("\n=== Initialization Successful ===")
print("서버를 실행하려면: uvicorn main:app --reload")
