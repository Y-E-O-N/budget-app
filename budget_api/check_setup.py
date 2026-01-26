#!/usr/bin/env python
"""Setup status checker - Shows what needs to be configured"""
import os
import sys
from pathlib import Path

# .env 파일 경로
env_path = Path(__file__).parent / '.env'

print("=" * 60)
print("Budget App Setup Status Checker")
print("=" * 60)

# .env 파일 존재 확인
if not env_path.exists():
    print("\n[ERROR] .env file not found!")
    print("Action: Copy budget_api/.env.example to budget_api/.env")
    sys.exit(1)

# 환경변수 로드
from dotenv import load_dotenv
load_dotenv()

issues = []
warnings = []
ok_items = []

print("\n[1] Required Settings")
print("-" * 60)

# Gemini API Key
gemini_key = os.getenv("GEMINI_API_KEY", "")
if not gemini_key or gemini_key == "test_api_key_placeholder":
    issues.append("GEMINI_API_KEY not set or using placeholder")
    print("[X] GEMINI_API_KEY: NOT SET or PLACEHOLDER")
    print("    Action: Get API key from https://aistudio.google.com/app/apikey")
elif len(gemini_key) < 20:
    warnings.append("GEMINI_API_KEY looks suspicious (too short)")
    print("[!] GEMINI_API_KEY: SET but may be invalid")
else:
    ok_items.append("GEMINI_API_KEY")
    print(f"[OK] GEMINI_API_KEY: {gemini_key[:10]}...{gemini_key[-4:]}")

# Admin API Key
admin_key = os.getenv("ADMIN_API_KEY", "")
if not admin_key or admin_key == "test_admin_key_12345":
    warnings.append("ADMIN_API_KEY not set or using weak key")
    print("[!] ADMIN_API_KEY: NOT SET or WEAK")
    print("    Action: Generate strong key with:")
    print("    python -c \"import secrets; print(secrets.token_hex(32))\"")
elif len(admin_key) < 16:
    warnings.append("ADMIN_API_KEY too weak (less than 16 chars)")
    print("[!] ADMIN_API_KEY: TOO WEAK")
else:
    ok_items.append("ADMIN_API_KEY")
    print(f"[OK] ADMIN_API_KEY: {admin_key[:8]}...{admin_key[-4:]} (strong)")

print("\n[2] Optional Settings")
print("-" * 60)

# CORS
allowed_origins = os.getenv("ALLOWED_ORIGINS", "")
if not allowed_origins:
    print("[INFO] ALLOWED_ORIGINS: Not set (using localhost)")
    print("       OK for development, set for production")
else:
    print(f"[OK] ALLOWED_ORIGINS: {allowed_origins}")
    ok_items.append("ALLOWED_ORIGINS")

# Rate Limiting
rate_limit = os.getenv("IP_RATE_LIMIT_PER_MINUTE", "10")
print(f"[OK] IP_RATE_LIMIT_PER_MINUTE: {rate_limit}")

# Database
db_url = os.getenv("DATABASE_URL", "")
if db_url:
    print(f"[OK] DATABASE_URL: {db_url.split('@')[0]}@... (PostgreSQL)")
    ok_items.append("DATABASE_URL")
else:
    print("[INFO] DATABASE_URL: Not set (using SQLite)")

print("\n[3] Summary")
print("-" * 60)
print(f"OK Items: {len(ok_items)}")
print(f"Warnings: {len(warnings)}")
print(f"Issues: {len(issues)}")

if issues:
    print("\n[CRITICAL] You must fix these issues:")
    for i, issue in enumerate(issues, 1):
        print(f"  {i}. {issue}")

if warnings:
    print("\n[WARNING] Consider fixing these:")
    for i, warning in enumerate(warnings, 1):
        print(f"  {i}. {warning}")

print("\n" + "=" * 60)
if not issues:
    print("[SUCCESS] Basic setup complete!")
    print("Next: Run 'uvicorn main:app --reload' to start server")
else:
    print("[ACTION REQUIRED] Fix critical issues above")
    print("See SETUP_GUIDE.md for detailed instructions")
print("=" * 60)
