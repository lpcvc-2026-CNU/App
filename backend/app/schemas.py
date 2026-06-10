from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional

# ─────────────────────────────────────────────────────────────────────────────
# 1. 인증 및 회원 관련 스키마 (Auth / User Schemas)
# ─────────────────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    email: EmailStr = Field(..., description="로그인 계정 이메일")
    password: str = Field(..., min_length=8, description="비밀번호 (최소 8자 이상)")
    nickname: str = Field(..., min_length=1, max_length=100, description="닉네임")
    push_token: Optional[str] = Field(None, description="알림용 FCM 푸시 토큰")

    @field_validator("password")
    @classmethod
    def validate_password_complexity(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("비밀번호는 최소 8자 이상이어야 합니다.")
        return v

class UserLogin(BaseModel):
    email: EmailStr = Field(..., description="로그인 계정 이메일")
    password: str = Field(..., description="비밀번호")
    push_token: Optional[str] = Field(None, description="갱신할 알림용 FCM 푸시 토큰")

class TokenResponse(BaseModel):
    access_token: str = Field(..., description="Bearer JWT 토큰 문자열")
    token_type: str = Field("bearer", description="토큰 타입")
    nickname: str = Field(..., description="사용자 닉네임")

# ─────────────────────────────────────────────────────────────────────────────
# 2. 랜드마크 관련 스키마 (Landmark Schemas)
# ─────────────────────────────────────────────────────────────────────────────

class LandmarkResponse(BaseModel):
    id: str
    name_ko: str
    name_en: str
    name_zh: str
    name_ja: str
    district: Optional[str] = None
    description_ko: Optional[str] = None
    description_en: Optional[str] = None
    description_zh: Optional[str] = None
    description_ja: Optional[str] = None
    latitude: float
    longitude: float

    class Config:
        from_attributes = True