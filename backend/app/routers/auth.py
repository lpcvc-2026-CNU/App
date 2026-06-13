import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from app.database import get_db
from app.models import User
from app.schemas import UserRegister, UserLogin, TokenResponse
from app.security import (
    SECRET_KEY,
    ALGORITHM,
    verify_password,
    get_password_hash,
    create_access_token
)

router = APIRouter(prefix="/api/auth", tags=["Auth"])

# OAuth2 패스워드 그랜트 방식에 기반한 Bearer 토큰 추출 스키마
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    """인증 가드 디펜던시: JWT 유효성 검증 및 현재 요청 유저 반환"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="인증 자격 증명이 유효하지 않거나 만료되었습니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    return user


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """회원가입 API (비밀번호는 schemas.py에서 8자 이상 강제 검증됨)"""
    # 1. 이메일 중복 체크
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 가입된 이메일 주소입니다."
        )
    
    # 2. 유저 객체 생성 및 저장
    new_user = User(
        id=str(uuid.uuid4()),
        email=user_data.email,
        hashed_password=get_password_hash(user_data.password),
        nickname=user_data.nickname,
        push_token=user_data.push_token
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "회원가입이 성공적으로 완료되었습니다.", "user_id": new_user.id}


@router.post("/login", response_model=TokenResponse)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """로그인 API (인증 성공 시 Access Token 및 닉네임 반환)"""
    # 1. 이메일 기준으로 유저 조회
    user = db.query(User).filter(User.email == user_data.email).first()
    if user is None or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="이메일 또는 비밀번호가 올바르지 않습니다."
        )
    
    # 2. 로그인 성공 시 FCM 토큰이 함께 오면 갱신 처리
    if user_data.push_token:
        user.push_token = user_data.push_token
        db.commit()
        db.refresh(user)
        
    # 3. 토큰 발급
    access_token = create_access_token(data={"sub": user.id})
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        nickname=user.nickname
    )


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """로그아웃 API (클라이언트의 푸시 알림 비활성화를 위해 FCM 토큰 삭제 처리)"""
    current_user.push_token = None
    db.commit()
    return {"message": "성공적으로 로그아웃되었습니다."}


@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    """현재 로그인 유저 정보 조회 API"""
    return {
        "id": current_user.id,
        "email": current_user.email,
        "nickname": current_user.nickname,
        "is_admin": current_user.is_admin,
        "push_token": current_user.push_token,
        "created_at": current_user.created_at
    }


@router.delete("/withdraw")
def withdraw(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """회원 탈퇴 API (데이터 삭제 및 토큰 파기)"""
    db.delete(current_user)
    db.commit()
    return {"message": "회원 탈퇴가 완료되었습니다."}


@router.patch("/fcm-token")
def update_fcm_token(push_token: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """FCM 디바이스 토큰 개별 업데이트 API"""
    current_user.push_token = push_token
    db.commit()
    return {"message": "FCM 토큰이 성공적으로 업데이트되었습니다."}