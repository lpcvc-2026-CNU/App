import os
import logging
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials

from app.database import engine
from app.models import Base
from app.routers import auth, landmarks, notifications, suggestions

# 로거 설정
logger = logging.getLogger("uvicorn.error")

# 데이터베이스 테이블 자동 생성 (실제 운영계 서비스 적용 시에는 Alembic 마이그레이션 도구 권장)
Base.metadata.create_all(bind=engine)

# Firebase Admin SDK 초기화 시도
service_account_path = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "firebase-service-account.json")
)

if os.path.exists(service_account_path):
    try:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
        logger.info("[Firebase] Firebase Admin SDK가 성공적으로 초기화되었습니다.")
    except Exception as e:
        logger.error(f"[Firebase] Firebase Admin SDK 초기화 중 에러가 발생했습니다: {str(e)}")
else:
    logger.warning(
        f"[Firebase] {service_account_path} 파일이 존재하지 않습니다. "
        "FCM 푸시 알림은 MOCK 모드로 작동합니다."
    )

app = FastAPI(
    title="Seoul Landmark Assistant - Backend Service",
    description="랜드마크 다국어 관리 및 JWT 회원 인증, 1기기 1계정 푸시 알림 관리를 담당하는 코어 API 서비스",
    version="1.0.0"
)

# CORS 설정 (모바일 앱 클라이언트 접속 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실무 배포 시 특정 도메인 및 클라이언트로 축소 적용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(auth.router)
app.include_router(landmarks.router)
app.include_router(notifications.router)
app.include_router(suggestions.router)


@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "Seoul Landmark Assistant Backend",
        "documentation": "/docs"
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)