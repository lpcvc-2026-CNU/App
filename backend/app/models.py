from sqlalchemy import Column, String, Text, Numeric, DateTime, func
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

class User(Base):
    __tablename__ = "users"

    id = Column(String(100), primary_key=True, comment="사용자 고유 식별자")
    email = Column(String(255), unique=True, nullable=False, index=True, comment="이메일")
    hashed_password = Column(String(255), nullable=False, comment="비밀번호 해시")
    nickname = Column(String(100), nullable=False, comment="닉네임")
    push_token = Column(String(255), nullable=True, comment="FCM 푸시 토큰")
    created_at = Column(DateTime, server_default=func.now(), comment="가입일시")