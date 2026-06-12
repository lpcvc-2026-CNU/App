import os
import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional, List
from app.database import get_db
from app.models import User, Notification
from app.schemas import NotificationResponse
from app.routers.auth import get_current_user

# Firebase Admin SDK
import firebase_admin
from firebase_admin import messaging

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])
logger = logging.getLogger("uvicorn.error")

class SendNotificationRequest(BaseModel):
    user_email: Optional[str] = Field(None, description="수신인 유저 이메일 (token이 없을 때 사용)")
    push_token: Optional[str] = Field(None, description="직접 입력할 FCM 푸시 토큰 (우선순위)")
    title: str = Field(..., description="알림 제목")
    body: str = Field(..., description="알림 내용")


def send_push_notification_helper(token: str, title: str, body: str) -> dict:
    """푸시 알림을 발송하는 공통 헬퍼 함수 (FCM 연동 또는 Mock 모드 작동)"""
    firebase_ready = False
    try:
        # firebase_admin 앱이 등록되어 있고 자격 증명이 세팅되었는지 확인
        firebase_admin.get_app()
        firebase_ready = True
    except ValueError:
        # 초기화가 안 되었을 때
        pass

    if firebase_ready:
        try:
            # FCM 메시지 객체 생성
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                token=token,
            )
            # 알림 발송
            response = messaging.send(message)
            logger.info(f"[FCM] 알림 발송 성공: {response}")
            return {
                "status": "success",
                "mode": "FCM",
                "message_id": response,
                "target_token": token,
                "title": title,
                "body": body
            }
        except Exception as e:
            logger.error(f"[FCM] 알림 발송 오류: {str(e)}")
            return {
                "status": "failed",
                "mode": "FCM",
                "error": str(e),
                "target_token": token,
                "title": title,
                "body": body
            }
    else:
        # Mock 모드: 콘솔에 로그 출력
        logger.warning(
            f"[MOCK NOTIFICATION] 푸시 알림이 발송되었습니다 (Firebase 미설정 상태).\n"
            f"대상 토큰: {token}\n"
            f"제목: {title}\n"
            f"내용: {body}"
        )
        return {
            "status": "success",
            "mode": "Mock",
            "message": "Firebase Admin SDK가 설정되지 않아 Mock 콘솔 로그 발송을 수행했습니다.",
            "target_token": token,
            "title": title,
            "body": body
        }


@router.post("/send")
def send_notification(payload: SendNotificationRequest, db: Session = Depends(get_db)):
    """푸시 알림 발송 테스트 API (FCM 연동 또는 Mock 모드 작동)"""
    token = payload.push_token
    
    # 1. 만약 이메일로 발송을 요청한 경우 DB에서 해당 유저의 push_token 조회
    if not token and payload.user_email:
        user = db.query(User).filter(User.email == payload.user_email).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="지정된 이메일의 사용자를 찾을 수 없습니다."
            )
        token = user.push_token
        if not token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="해당 사용자는 등록된 푸시 토큰이 없습니다."
            )

    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="푸시 알림을 발송하기 위해 push_token 또는 user_email이 필요합니다."
        )

    result = send_push_notification_helper(token, payload.title, payload.body)
    if result.get("status") == "failed":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"FCM 알림 발송 실패: {result.get('error')}"
        )
    return result


@router.get("", response_model=List[NotificationResponse])
def get_my_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """현재 로그인한 사용자의 알림 이력 목록 조회 (최신순)"""
    return db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).order_by(Notification.created_at.desc()).all()


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def read_notification(
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """지정한 알림을 읽음 처리로 업데이트"""
    notification = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 알림을 찾을 수 없거나 접근 권한이 없습니다."
        )
    
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification
