from sqlalchemy import Column, String, Text, Numeric, DateTime, Boolean, ForeignKey, func, Integer, Float
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Landmark(Base):
    __tablename__ = "landmarks"

    id = Column(String(100), primary_key=True, comment="랜드마크 고유 식별자")
    name_ko = Column(String(255), nullable=False, comment="한국어 명칭")
    name_en = Column(String(255), nullable=False, comment="영어 명칭")
    name_zh = Column(String(255), nullable=False, comment="중국어 명칭")
    name_ja = Column(String(255), nullable=False, comment="일본어 명칭")
    district = Column(String(100), nullable=True, index=True, comment="행정구역 (구)")
    description_ko = Column(Text, nullable=True, comment="한국어 개요")
    description_en = Column(Text, nullable=True, comment="영어 개요")
    description_zh = Column(Text, nullable=True, comment="중국어 개요")
    description_ja = Column(Text, nullable=True, comment="일본어 개요")
    latitude = Column(Numeric(10, 8), nullable=False, comment="위도")
    longitude = Column(Numeric(11, 8), nullable=False, comment="경도")
    parent_landmark_id = Column(String(100), ForeignKey("landmarks.id", ondelete="SET NULL"), nullable=True, comment="상위 랜드마크 식별자")

class User(Base):
    __tablename__ = "users"

    id = Column(String(100), primary_key=True, comment="사용자 고유 식별자")
    email = Column(String(255), unique=True, nullable=False, index=True, comment="이메일")
    hashed_password = Column(String(255), nullable=False, comment="비밀번호 해시")
    nickname = Column(String(100), nullable=False, comment="닉네임")
    push_token = Column(String(255), nullable=True, comment="FCM 푸시 토큰")
    is_admin = Column(Boolean, default=False, nullable=False, comment="관리자 여부")
    created_at = Column(DateTime, server_default=func.now(), comment="가입일시")

class Suggestion(Base):
    __tablename__ = "suggestions"

    id = Column(String(100), primary_key=True, comment="건의 사항 고유 ID (UUID)")
    user_id = Column(String(100), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True, comment="제출 사용자 ID")
    landmark_name = Column(String(255), nullable=False, comment="건의할 랜드마크 이름")
    description = Column(Text, nullable=False, comment="랜드마크 상세 설명")
    status = Column(String(50), nullable=False, default="pending", index=True, comment="건의 처리 상태 (pending, approved, rejected, completed)")
    rejection_reason = Column(String(255), nullable=True, comment="반려 사유 (반려 시에만 기록)")
    created_at = Column(DateTime, server_default=func.now(), comment="제출 일시")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), comment="수정 일시")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String(100), primary_key=True, comment="알림 고유 ID (UUID)")
    user_id = Column(String(100), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True, comment="수신 사용자 ID")
    title = Column(String(255), nullable=False, comment="알림 제목")
    body = Column(Text, nullable=False, comment="알림 내용")
    is_read = Column(Boolean, default=False, nullable=False, comment="읽음 여부")
    created_at = Column(DateTime, server_default=func.now(), comment="생성 일시")


class SearchLog(Base):
    __tablename__ = "search_logs"

    id = Column(Integer, primary_key=True, autoincrement=True, comment="로그 고유 식별자")
    timestamp = Column(String(100), nullable=False, comment="로그 기록 일시 (ISO 형식)")
    query_type = Column(String(50), nullable=False, comment="검색 쿼리 타입 (image, text)")
    top1_id = Column(String(100), nullable=True, comment="탑 1 결과 랜드마크 ID")
    decision = Column(String(50), nullable=True, comment="결정 유형")
    reason_codes = Column(String(255), nullable=True, comment="결정 이유 코드")
    latency_ms = Column(Integer, nullable=True, comment="소요 시간 (ms)")
    model_version = Column(String(100), nullable=True, comment="모델 버전")
    backend = Column(String(100), nullable=True, comment="백엔드 유형")
    top3_scores = Column(Text, nullable=True, comment="Top 3 결과 및 점수")
    margin = Column(Float, nullable=True, comment="Margin 점수 차이")
    decision_status = Column(String(50), nullable=True, comment="최종 결정 상태")
