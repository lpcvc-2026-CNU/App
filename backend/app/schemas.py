from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from typing import Optional
from datetime import datetime

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

# ─────────────────────────────────────────────────────────────────────────────
# 3. 건의 사항 관련 스키마 (Suggestion Schemas)
# ─────────────────────────────────────────────────────────────────────────────

class SuggestionCreate(BaseModel):
    landmark_name: str = Field(..., min_length=1, max_length=255, description="건의할 랜드마크 이름")
    description: str = Field(..., min_length=1, description="랜드마크에 대한 간단한 설명")

class SuggestionStatusUpdate(BaseModel):
    status: str = Field(..., description="변경할 상태 ('approved', 'rejected', 'completed')")
    rejection_reason: Optional[str] = Field(None, description="반려 사유 (rejected일 경우 필수)")

    @model_validator(mode="after")
    def check_rejection_reason(self) -> "SuggestionStatusUpdate":
        if self.status not in ["approved", "rejected", "completed"]:
            raise ValueError("status는 'approved', 'rejected', 'completed' 중 하나여야 합니다.")
        if self.status == "rejected":
            if not self.rejection_reason or not self.rejection_reason.strip():
                raise ValueError("반려 상태로 변경 시 반려 사유(rejection_reason)는 필수이며 비어있을 수 없습니다.")
        return self

class SuggestionResponse(BaseModel):
    id: str
    user_id: str
    landmark_name: str
    description: str
    status: str
    rejection_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────────────────────
# 4. 알림 관련 스키마 (Notification Schemas)
# ─────────────────────────────────────────────────────────────────────────────

class NotificationResponse(BaseModel):
    id: str
    user_id: str
    title: str
    body: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True