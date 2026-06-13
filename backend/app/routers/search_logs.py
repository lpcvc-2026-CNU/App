from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import SearchLog
from app.schemas import SearchLogCreate, SearchLogResponse

router = APIRouter(prefix="/api/search/logs", tags=["Search Logs"])

@router.post("", response_model=SearchLogResponse, status_code=status.HTTP_201_CREATED)
def create_search_log(log_in: SearchLogCreate, db: Session = Depends(get_db)):
    """
    모바일 앱에서 발생한 검색 로그를 서버 데이터베이스에 저장합니다.
    """
    try:
        db_log = SearchLog(
            timestamp=log_in.timestamp,
            query_type=log_in.query_type,
            top1_id=log_in.top1_id,
            decision=log_in.decision,
            reason_codes=log_in.reason_codes,
            latency_ms=log_in.latency_ms,
            model_version=log_in.model_version,
            backend=log_in.backend,
            top3_scores=log_in.top3_scores,
            margin=log_in.margin,
            decision_status=log_in.decision_status
        )
        db.add(db_log)
        db.commit()
        db.refresh(db_log)
        return db_log
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"검색 로그 저장 중 오류가 발생했습니다: {str(e)}"
        )
