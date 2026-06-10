from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Landmark
from app.schemas import LandmarkResponse

router = APIRouter(prefix="/api/landmarks", tags=["Landmarks"])

@router.get("", response_model=List[LandmarkResponse])
def read_landmarks(db: Session = Depends(get_db)):
    """
    모든 랜드마크의 다국어 이름, 상세설명, 위경도 정보를 데이터베이스로부터 조회하여 리턴합니다.
    클라이언트 측 데이터 중복 체크 및 마스터 매핑용으로 사용됩니다.
    """
    try:
        landmarks = db.query(Landmark).all()
        return landmarks
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"데이터베이스 조회 오류가 발생했습니다: {str(e)}"
        )