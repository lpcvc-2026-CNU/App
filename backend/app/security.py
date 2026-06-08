import os
import bcrypt
from datetime import datetime, timedelta
from typing import Optional
from jose import jwt

# 보안 민감 설정
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "7b686d63df481ea63dc2b8b9ad43bc8a77a6411516e8d2e8b2b9c3f4e5d6c7b8")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """평문 비밀번호와 해싱 비밀번호 대조 검증 (passlib 의존성 제거형)"""
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'), 
            hashed_password.encode('utf-8')
        )
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    """평문 비밀번호 해싱 처리 (passlib 의존성 제거형)"""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def create_
<truncated 594 bytes>
동 시 물리 테이블을 MySQL 데이터베이스에 자동 생성해 주는 전체 진입점 코드입니다. (이 파일은 기존 형태 그대로 사용하셔도 완벽히 호환됩니다.)
