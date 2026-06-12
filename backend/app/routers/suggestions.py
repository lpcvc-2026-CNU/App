import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

from app.database import get_db
from app.models import User, Landmark, Suggestion
from app.schemas import SuggestionCreate, SuggestionStatusUpdate, SuggestionResponse
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/suggestions", tags=["Suggestions"])

def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """관리자 권한 확인 디펜던시"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="이 작업을 수행할 권한이 없습니다. 관리자만 접근 가능합니다."
        )
    return current_user


@router.post("", response_model=SuggestionResponse, status_code=status.HTTP_201_CREATED)
def create_suggestion(
    payload: SuggestionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """랜드마크 추가 건의 제출 (유연한 중복 검증 탑재)"""
    # 1. 입력 텍스트 유연하게 정규화 (앞뒤 공백 제거 및 모든 공백 무시, 소문자화)
    input_name = payload.landmark_name.strip()
    normalized_input = "".join(input_name.split()).lower()
    
    if not input_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="랜드마크 이름은 비어있을 수 없습니다."
        )

    # 2. 기존 13개 공식 랜드마크 목록과 대조 검증
    all_landmarks = db.query(Landmark).all()
    for lm in all_landmarks:
        # 한국어 명칭 공백 제거 대조
        lm_ko = "".join(lm.name_ko.split()).lower() if lm.name_ko else ""
        # 영어 명칭 공백 제거 대조
        lm_en = "".join(lm.name_en.split()).lower() if lm.name_en else ""
        
        if normalized_input == lm_ko or normalized_input == lm_en:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"이미 등록되어 있는 랜드마크입니다. (공식 명칭: {lm.name_ko})"
            )

    # 3. 이미 제출되어 대기(pending) 중이거나 승인(approved)된 건의 목록과 대조 검증
    existing_suggestions = db.query(Suggestion).filter(
        Suggestion.status.in_(["pending", "approved"])
    ).all()
    for sug in existing_suggestions:
        sug_name = "".join(sug.landmark_name.split()).lower()
        if normalized_input == sug_name:
            status_desc = "검토 대기 중" if sug.status == "pending" else "이미 추가 승인됨"
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"이미 동일한 건의 사항이 존재합니다. ({status_desc})"
            )

    # 4. 신규 건의 사항 등록
    new_suggestion = Suggestion(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        landmark_name=input_name,
        description=payload.description.strip(),
        status="pending"
    )
    db.add(new_suggestion)
    db.commit()
    db.refresh(new_suggestion)
    return new_suggestion


@router.get("/my", response_model=List[SuggestionResponse])
def get_my_suggestions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """현재 로그인한 유저가 제출한 건의 사항 목록 조회 (최신순)"""
    return db.query(Suggestion).filter(
        Suggestion.user_id == current_user.id
    ).order_by(Suggestion.created_at.desc()).all()


@router.get("", response_model=List[SuggestionResponse])
def get_all_suggestions(
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    """개발자(관리자)용 모든 유저의 건의 사항 전체 조회 (최신순)"""
    return db.query(Suggestion).order_by(Suggestion.created_at.desc()).all()


@router.patch("/{suggestion_id}/status", response_model=SuggestionResponse)
def update_suggestion_status(
    suggestion_id: str,
    payload: SuggestionStatusUpdate,
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    """개발자(관리자)용 건의 사항 상태 변경 (승인/반려 처리)"""
    suggestion = db.query(Suggestion).filter(Suggestion.id == suggestion_id).first()
    if not suggestion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 건의 사항을 찾을 수 없습니다."
        )

    # status가 rejected 인데 사유가 공백이거나 누락되었는지 다시 한 번 체크 (안전 장치)
    if payload.status == "rejected":
        if not payload.rejection_reason or not payload.rejection_reason.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="반려 처리 시 반려 사유(rejection_reason)를 반드시 입력해야 합니다."
            )
        suggestion.rejection_reason = payload.rejection_reason.strip()
    else:
        # approved 등 반려가 아닌 상태로 전환될 시 사유는 초기화
        suggestion.rejection_reason = None

    suggestion.status = payload.status
    db.commit()
    db.refresh(suggestion)

    # 관리자 상태 변경에 따른 알림 생성 및 실시간 푸시 발송 트리거
    title = ""
    body = ""
    if suggestion.status == "approved":
        title = "랜드마크 건의 승인"
        body = f"제안하신 '{suggestion.landmark_name}' 건의가 승인되었습니다."
    elif suggestion.status == "rejected":
        title = "랜드마크 건의 반려"
        body = f"제안하신 '{suggestion.landmark_name}' 건의가 반려되었습니다. 사유: {suggestion.rejection_reason}"

    if title and body:
        # DB 알림 내역 저장
        from app.models import Notification
        new_notification = Notification(
            id=str(uuid.uuid4()),
            user_id=suggestion.user_id,
            title=title,
            body=body,
            is_read=False
        )
        db.add(new_notification)
        db.commit()

        # 푸시 토큰 조회 후 실시간 발송
        target_user = db.query(User).filter(User.id == suggestion.user_id).first()
        if target_user and target_user.push_token:
            from app.routers.notifications import send_push_notification_helper
            send_push_notification_helper(
                token=target_user.push_token,
                title=title,
                body=body
            )

    return suggestion
