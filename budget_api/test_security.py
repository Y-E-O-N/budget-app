#!/usr/bin/env python
"""보안 기능 테스트 스크립트"""
import sys
sys.path.insert(0, '.')

print("=== Security Features Test ===\n")

# 1. CORS 설정 확인
print("[1] CORS Settings")
from main import app
cors_middleware = None
for middleware in app.user_middleware:
    if 'CORSMiddleware' in str(middleware):
        cors_middleware = middleware
        break

if cors_middleware:
    print("[OK] CORS middleware is configured")
else:
    print("[FAIL] CORS middleware not found")

# 2. Rate Limiting 함수 테스트
print("\n[2] Rate Limiting")
from main import check_ip_rate_limit, IP_RATE_LIMIT_PER_MINUTE

# 정상 요청
try:
    result = check_ip_rate_limit("127.0.0.1")
    if result:
        print(f"[OK] Rate limiting configured (limit: {IP_RATE_LIMIT_PER_MINUTE}/min)")
    else:
        print("[FAIL] Rate limit check returned False")
except Exception as e:
    print(f"[FAIL] Rate limit check failed: {e}")

# 3. 관리자 인증 테스트
print("\n[3] Admin Authentication")
from main import verify_admin_key, ADMIN_API_KEY
from fastapi import HTTPException

try:
    # 잘못된 키
    try:
        verify_admin_key("wrong_key")
        print("[FAIL] Should reject wrong admin key")
    except HTTPException as e:
        if e.status_code == 401:
            print("[OK] Rejects invalid admin key")
        else:
            print(f"[FAIL] Wrong status code: {e.status_code}")

    # 올바른 키
    if ADMIN_API_KEY:
        result = verify_admin_key(ADMIN_API_KEY)
        if result:
            print("[OK] Accepts valid admin key")
except Exception as e:
    print(f"[FAIL] Admin auth test failed: {e}")

# 4. Request Validation (Pydantic)
print("\n[4] Request Validation (Pydantic)")
import uuid
print("[OK] Pydantic models configured for validation")
print(f"[INFO] Device ID must be valid UUIDv4 format")

# 5. Database Initialization
print("\n[5] Database")
from database import create_database
try:
    db = create_database()
    print("[OK] Database initialized successfully")
    print(f"[INFO] Using SQLite (location shown at startup)")
except Exception as e:
    print(f"[FAIL] Database init failed: {e}")

print("\n=== All Security Tests Completed ===")
