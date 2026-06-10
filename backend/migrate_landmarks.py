import os
import json
from decimal import Decimal
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app.models import Base, Landmark

def migrate_data():
    # 데이터베이스 테이블 생성 확인
    Base.metadata.create_all(bind=engine)
    
    # 랜드마크 JSON 마스터 데이터 경로 (프로젝트 assets 폴더 기준)
    json_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "landmark_info.json"))
    
    if not os.path.exists(json_path):
        print(f"[오류] 원본 landmark_info.json 파일을 찾을 수 없습니다: {json_path}")
        return

    print(f"[정보] {json_path} 로부터 랜드마크 데이터를 읽어옵니다...")
    
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        items = data.get("items", [])

    db: Session = SessionLocal()
    try:
        # 1. 중복 삽입 방지를 위한 기존 데이터 초기화 (선택적)
        existing_count = db.query(Landmark).count()
        if existing_count > 0:
            print(f"[정보] 데이터베이스에 이미 {existing_count}개의 랜드마크가 존재합니다. 기존 데이터를 삭제하고 최신화합니다.")
            db.query(Landmark).delete()
            db.commit()

        # 2. JSON 데이터 파싱 및 INSERT 수행
        for item in items:
            description_ko = item.get("description_ko", "")
            district = "알수없음"
            
            # 설명글에서 '구' 단어 검색 및 자동 매핑
            import re
            match = re.search(r'([가-힣]+구)', description_ko)
            if match:
                district = match.group(1)

            landmark = Landmark(
                id=item["landmark_id"],
                name_ko=item["name_ko"],
                name_en=item["name_en"],
                name_zh=item["name_zh"],
                name_ja=item["name_ja"],
                district=district,
                description_ko=item.get("description_ko"),
                description_en=item.get("description_en"),
                description_zh=item.get("description_zh"),
                description_ja=item.get("description_ja"),
                latitude=Decimal(str(item["latitude"])),
                longitude=Decimal(str(item["longitude"]))
            )
            db.add(landmark)
        
        db.commit()
        print(f"[성공] 총 {len(items)}개의 랜드마크 데이터를 데이터베이스에 성공적으로 마이그레이션했습니다.")

    except Exception as e:
        db.rollback()
        print(f"[오류] 마이그레이션 도중 에러가 발생했습니다: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    migrate_data()