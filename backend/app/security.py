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

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
