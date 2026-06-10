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
    """회원가입 API"""
    # 1. 이메일 중복 체크
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 가입된 이메일 주소입니다."
        )

    # 2. 1계정 1기기 정책: 신규 가입 시 제공된 push_token이 있다면 다른 유저에게서 토큰 제거
    if user_data.push_token:
        db.query(User).filter(User.push_token == user_data.push_token).update({User.push_token: None})

    # 3. 유저 생성
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
    return {"message": "회원가입이 완료되었습니다.", "user_id": new_user.id}


@router.post("/login", response_model=TokenResponse)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """로그인 API (JWT 토큰 반환 & 푸시 토큰 갱신)"""
    user = db.query(User).filter(User.email == user_data.email).first()
    if not user or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이메일 또는 비밀번호가 잘못되었습니다."
        )

    # 1계정 1기기 정책 적용
    if user_data.push_token:
        # 동일한 푸시 토큰을 점유하고 있는 기존 유저의 토큰을 초기화 (중복 무효화)
        db.query(User).filter(User.push_token == user_data.push_token).update({User.push_token: None})
        user.push_token = user_data.push_token
    
    db.commit()

    # JWT Access Token 생성
    access_token = create_access_token(data={"sub": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "nickname": user.nickname
    }


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """로그아웃 API (푸시 토큰 갱신 해제)"""
    current_user.push_token = None
    db.commit()
    return {"message": "로그아웃 되었으며, 푸시 알림 수신이 해제되었습니다."}