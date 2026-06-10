import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# 환경변수로부터 데이터베이스 URL 획득
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    # 로컬 개발 환경 편의성을 위한 SQLite 자동 Fallback 설정
    db_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "landmark_local.db")
    )
    DATABASE_URL = f"sqlite:///{db_path}"
    print(f"[Database] DATABASE_URL 환경변수가 없어 로컬 SQLite를 사용합니다: {db_path}")

is_sqlite = DATABASE_URL.startswith("sqlite")

# SQLite 사용 시 멀티스레드 접속 허용 설정 추가
connect_args = {"check_same_thread": False} if is_sqlite else {}

engine_options = {
    "pool_pre_ping": True,
    "connect_args": connect_args
}

if not is_sqlite:
    engine_options["pool_size"] = 10
    engine_options["max_overflow"] = 20

engine = create_engine(DATABASE_URL, **engine_options)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """FastAPI API 호출별 DB 세션 생명주기 관리용 제너레이터"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()