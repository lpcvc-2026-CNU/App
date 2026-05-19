# 📖 Landmark Assistant Flutter App – 프로젝트 README

> **작성일:** 2026‑05‑18
> **작성자:** Antigravity (AI 코딩 어시스턴트)

---

## 1️⃣ 프로젝트 개요
`Landmark Assistant`는 사용자가 **이미지** 혹은 **텍스트 키워드**를 입력하면, 온‑디바이스 ONNX 모델을 이용해 **지원 범위 내 랜드마크**를 찾아 Top‑3 후보를 보여주는 모바일 어시스턴스 앱입니다.

- **핵심 목표**
  1. 이미지 입력 → ONNX 추론 → 임베딩 추출 → 코사인 유사도 기반 후보 검색
  2. 텍스트 키워드 검색 → SQLite/Asset DB 조회 → 후보 리스트 표시
  3. 사용자가 검색 결과를 클릭하면 상세 정보 화면으로 이동
  4. 저품질·범위‑외 입력에 대한 친절한 안내 UI 제공

- **기술 스택**
  - Flutter (Dart)
  - ONNX Runtime for Flutter (`onnxruntime` 패키지)
  - SQLite (`sqflite`) + 로컬 JSON (`landmark_info.json`)
  - 이미지 전처리 (`image` 패키지)

---

## 2️⃣ 현재까지 진행 상황 & 구현 내용

| # | 작업 내용 | 구현 파일 | 주요 구현 포인트 |
|---|-----------|-----------|------------------|
| 1 | **ONNX 모델 파일 복사** | `flutter_app/assets/mobile_artifacts_int8/` | `landmark_encoder.onnx`·`prototype_index.json` 등 전체 모델 파일을 앱 assets에 포함 |
| 2 | **이미지 전처리 + 임베딩 추출** | `lib/services/onnx_inference_service.dart` | <ul><li>`dart:typed_data` 임포트</li><li>이미지 디코딩 → 256px 리사이즈 → 224×224 중앙 크롭</li><li>RGB 정규화 (mean/std)</li><li>Float32 Tensor(`OrtValueTensor`) 생성 → `session.run` 실행 → 512‑차원 임베딩 반환</li></ul> |
| 3 | **코사인 유사도 기반 후보 검색** | `lib/api/local_api_client_impl.dart` | <ul><li>`prototype_index.json` 로드 및 캐시</li><li>코사인 유사도 함수 구현 (`_cosineSimilarity`) </li><li>임베딩과 모든 프로토타입 간 점수 계산 → Top‑3 정렬 후 반환</li></ul> |
| 4 | **검색 결과 UI 개선** | `lib/ui/screens/result_screen.dart` | <ul><li>결과 화면에서 `%` 문자열 보간 오류(`\${}` → `$`) 수정</li><li>이미지 후보와 일치율 표시 UI 유지</li></ul> |
| 5 | **텍스트 검색 UI/UX 개선** | `lib/ui/screens/text_search_screen.dart` | <ul><li>검색 시 `FocusScope.of(context).unfocus()` 로 키보드 자동 숨김</li><li>TextField에 `textInputAction: TextInputAction.search` 설정</li></ul> |
| 6 | **홈 화면 이미지 검색 로직 교체** | `lib/ui/screens/home_screen.dart` | <ul><li>모크 데이터를 실제 `widget.apiClient.search` 호출 결과로 교체</li><li>예외 시 오류 로그(`print`) 출력</li></ul> |
| 7 | **앱 전역 에러 로깅** | `lib/ui/screens/home_screen.dart` | <ul><li>API 호출 실패 시 콘솔에 에러와 스택 트레이스 출력</li></ul> |
| 8 | **문서·작업 관리** | `implementation_plan.md`, `task.md`, `walkthrough.md` | 작업 진행 상황, 구현 계획, 검증 내용 정리 |

> **핵심 결과**
- 이미지 입력 시 **고정된 95%** 결과가 나오던 것이 실제 ONNX 추론 결과에 따라 동적으로 변함.
- 텍스트 검색 시 키보드가 남아 UI를 가리는 현상이 사라짐.
- 저품질·범위‑외 이미지 입력 시 `low_quality` 또는 `out_of_scope` 안내 화면이 정상 동작.

---

## 3️⃣ UI 페이지 상세 설명

### 3.1 HomeScreen (`home_screen.dart`)
| 구분 | 내용 |
|------|------|
| **기능** | <ul><li>상단에 이미지 선택 버튼 (카메라·갤러리)</li><li>‘키워드로 검색하기’ 버튼 → TextSearchScreen으로 이동</li><li>이미지를 선택하면 `LocalApiClient.search` 호출 → 결과를 `ResultScreen`에 전달</li></ul> |
| **주요 UI** | <ul><li>앱 로고 & 배경 (다크 모드 색상)</li><li>‘이미지 검색’ 카드 버튼</li><li>‘키워드 검색’ 카드 버튼</li></ul> |
| **버튼 액션** | <ul><li>`_onImageSelected` → 이미지 바이트를 API에 전달 → 반환된 `decision`에 따라 ResultScreen 또는 오류 Snackbar 표시</li><li>`_onKeywordSearchPressed` → `Navigator.push` 로 `TextSearchScreen` 이동</li></ul> |

### 3.2 ResultScreen (`result_screen.dart`)
| 구분 | 내용 |
|------|------|
| **기능** | <ul><li>이미지 검색 결과를 시각화</li><li>`decision`에 따라 UI 다중 분기:<br>• `matched` → 단일 후보/일치율 원형 게이지 표시 <br>• `ambiguous` → 후보 리스트와 안내 메세지 표시 <br>• `out_of_scope`/`low_quality` → 재촬영 안내</li></ul> |
| **주요 UI** | <ul><li>상단에 선택 이미지(미리보기)</li><li>결과 상태에 따라 원형 게이지, 후보 카드, 혹은 오류 안내 박스</li><li>‘다시 촬영하기’ 버튼 (low_quality/out_of_scope)</li></ul> |
| **버튼 액션** | <ul><li>`_showRetryButton` 클릭 → `Navigator.pop` 후 HomeScreen으로 돌아감</li></ul> |
| **주요 로직** | <ul><li>`_buildMatchedState()` – 일치율 원형 게이지 + 후보 카드 (이미지·이름·설명)</li><li>`_buildAmbiguousState()` – 후보 리스트와 “혹시 찾으시는 곳이 여기인가요?” 안내</li></ul> |

### 3.3 TextSearchScreen (`text_search_screen.dart`)
| 구분 | 내용 |
|------|------|
| **기능** | <ul><li>텍스트 키워드 입력 → `LocalApiClient.search` (textQuery 파라미터) 호출</li><li>결과(`top3`)를 UI에 카드 형태로 표시 (이미지·이름·설명)</li></ul> |
| **주요 UI** | <ul><li>앱 바(AppBar) – 뒤로 가기 버튼</li><li>검색 바 (`TextField`) – 검색어 입력 + 검색 아이콘</li><li>검색 중 로딩 인디케이터</li><li>검색 결과 리스트 (카드) – 클릭 시 상세 정보 화면(추후 구현 가능)으로 이동</li></ul> |
| **버튼/액션** | <ul><li>`_performSearch` – 엔터/검색 아이콘 클릭 시 키보드 자동 숨김 (`FocusScope.unfocus`) 후 API 호출</li><li>검색 결과가 없으면 “검색 결과가 없습니다” 메세지 표시</li></ul> |

### 3.4 기타 페이지 (미구현 단계)
| 페이지 | 예정 기능 |
|--------|-----------|
| 상세 정보 화면 (`detail_screen.dart` 등) | 선택된 랜드마크의 상세 설명, 지도 연동, 사진 갤러리 등 |
| 설정/로그 화면 | 검색 로그 조회, 모델 정보 확인 등 |

---

## 4️⃣ 페이지 흐름도 (Flowchart)
```mermaid
flowchart TD
    A[HomeScreen] -->|이미지 선택| B[ResultScreen]
    A -->|‘키워드 검색’ 클릭| C[TextSearchScreen]
    B -->|재촬영(또는 뒤로가기)| A
    C -->|검색어 입력 & 검색| D[ResultScreen (Text 결과)]
    D -->|다시 검색| C
    D -->|뒤로가기| A

    classDef home fill:#1e3a8a,color:#fff;
    classDef result fill:#047857,color:#fff;
    classDef text fill:#7c3aed,color:#fff;

    class A home;
    class B result;
    class C text;
    class D result;
```
- **HomeScreen** → 이미지 선택 → **ResultScreen** (이미지 결과) 
- **HomeScreen** → ‘키워드 검색’ → **TextSearchScreen** (텍스트 입력) 
- **TextSearchScreen** → 검색 → **ResultScreen** (텍스트 결과) 
- **ResultScreen** → ‘다시 촬영’ 또는 뒤로가기 → **HomeScreen** 
- **ResultScreen** → ‘다시 검색’(텍스트) → **TextSearchScreen** 

---

## 5️⃣ 프로젝트 구조 (핵심 디렉터리)
```
flutter_app/
├─ lib/
│  ├─ api/
│  │   ├─ local_api_client.dart               // 인터페이스 정의
│  │   └─ local_api_client_impl.dart          // 실제 구현 (ONNX 호출, DB 조회)
│  ├─ data/
│  │   └─ database_helper.dart                // SQLite 초기화·데이터 로드
│  ├─ services/
│  │   ├─ onnx_inference_service.dart         // 모델 초기화·임베딩 추출
│  │   └─ image_quality_service.dart          // 이미지 품질 검사 (low_quality 판단)
│  ├─ ui/
│  │   └─ screens/
│  │       ├─ home_screen.dart                // 메인 대시보드
│  │       ├─ result_screen.dart              // 이미지/텍스트 검색 결과
│  │       └─ text_search_screen.dart         // 텍스트 검색 입력·결과 화면
│  └─ main.dart                               // 앱 진입점 (API 초기화, 라우팅)
├─ assets/
│  ├─ hero_images/                             // 각 랜드마크 이미지
│  ├─ landmark_info.json                       // 메타데이터(이름·설명·좌표)
│  └─ mobile_artifacts_int8/
│        ├─ landmark_encoder.onnx               // ONNX 모델 파일
│        └─ prototype_index.json                // 랜드마크 임베딩 (프로토타입)
└─ pubspec.yaml
```

---

## 6️⃣ 테스트·검증 방법
| 단계 | 수행 내용 | 기대 결과 |
|------|-----------|-----------|
| 1️⃣ 이미지 검색 | 카메라·갤러리에서 사진 선택 | `ResultScreen`에 **동적 Top‑3 후보**와 일치율이 표시 |
| 2️⃣ 저품질 이미지 | 흐릿하거나 잘린 사진 입력 | `ResultScreen`에 **‘저품질 이미지’** 안내와 재촬영 버튼 등장 |
| 3️⃣ 텍스트 검색 | 검색바에 “경복궁” 입력 → 엔터 | `ResultScreen`에 **경복궁** 후보 카드가 표시 (이미지·설명) |
| 4️⃣ 키보드 UX | 텍스트 검색 후 엔터 | 키보드가 자동으로 사라지고 결과 리스트가 바로 보임 |
| 5️⃣ 오류 로그 | 의도적으로 잘못된 이미지·네트워크 차단 | 콘솔에 `Error during API search: ...` 로그가 출력되고 UI에 `out_of_scope` 표시 |

---

## 7️⃣ 향후 작업 (TODO)
- **상세 정보 페이지** 구현 (지도, 추가 사진, 설명 등) 
- **검색 로그 UI** (사용자 로그 보기) 
- **멀티플랫폼 빌드**(iOS, Android) 최적화 & NPU 가속 활성화 (NNAPI / CoreML) 
- **테스트 자동화** (Flutter integration test, unit test) 

---

## 8️⃣ 마무리
지금까지 **온‑디바이스 ONNX 추론, 코사인 유사도 기반 후보 검색, 텍스트 검색 UX 개선** 등을 구현함으로써, 프로젝트가 초기 “모크 데이터” 단계에서 **실제 모델 기반** 동작으로 전환되었습니다.

아래 명령어를 통해 앱을 다시 실행하고(핫 리스타트 `R`), 실제 이미지를 입력해 보시면 동적 결과를 확인하실 수 있습니다.

```bash
flutter run   # 혹은 이미 실행 중이라면 콘솔에서 R 키 눌러 Hot Restart
```

궁금한 점이나 추가 요구사항이 있으면 언제든 알려 주세요! 🚀
