# Seoul Landmark Assistant

서울 랜드마크 이미지 인식 및 상세 정보 조회를 제공하는 다국어 하이브리드 어플리케이션 프로젝트입니다. ONNX Runtime 기반의 디바이스 내 추론 기능 및 회원 가입/인증, 실시간 푸시 알림 인프라를 지원합니다.

---

## 🚀 2026.06.10 업데이트: FCM 푸시 알림 인프라 구축 및 연동

### 1. 백엔드 (FastAPI) 변경 사항
- **FCM 푸시 발송 인프라 통합**: `firebase-admin` 라이브러리를 추가하고, `firebase-service-account.json` 자격 증명서 파일이 백엔드 폴더 내에 존재할 경우 자동으로 FCM Admin SDK를 초기화하도록 설계했습니다.
- **Mock/Sandbox 모드 지원**: 로컬 개발 환경 및 Firebase 콘솔 설정이 완료되기 전에도 백엔드가 정상 기동하도록 안전 예외 처리(Try-Catch) 및 Mock 푸시 로그 출력 모드를 도입했습니다.
- **푸시 발송 테스트용 API 구현**: `POST /api/notifications/send` 엔드포인트를 구현하여 수신자의 `push_token` 혹은 가입 이메일을 바탕으로 실시간 푸시 알림을 즉시 발송하고 결과를 검증할 수 있습니다.
- **1기기 1계정 정책 강화**: 회원가입(`POST /api/auth/register`) 및 로그인(`POST /api/auth/login`) 요청 시 전달받은 `push_token`을 고유 기기 식별자로 삼아, 타 유저가 점유하고 있던 토큰을 자동으로 무효화(`None` 처리)합니다.
- **백엔드 파일 복구 및 핫픽스**: 기존에 깨져있던 Python 백엔드 코어 소스코드들(`models.py`, `schemas.py`, `security.py`, `auth.py`, `migrate_landmarks.py`)을 복구했으며, 추가적으로 `landmarks.py` 모듈이 문자열 형태로 인코딩되어 uvicorn 구동 시 발생하던 `AttributeError` 버그를 핫픽스(실제 코드로 복구) 완료했습니다.

### 2. 클라이언트 (Flutter App) 변경 사항
- **Firebase 패키지 의존성 추가**: `firebase_core` 및 `firebase_messaging` 모듈을 연동했습니다.
- **푸시 서비스 추상화 (`PushNotificationService`)**: 포그라운드/백그라운드 메시지 수신, 토큰 갱신 리스너 등록, iOS용 APNS 토큰 대기 등의 공통 인터페이스를 제공하는 싱글톤 서비스를 추가했습니다. 백엔드와 마찬가지로 Firebase 설정 파일 누락 시 자동으로 가상 디버그 토큰을 발급하는 Sandbox 모드를 탑재했습니다.
- **포그라운드 알림 사용자 인터페이싱**: 앱이 활성화된 포그라운드 상태에서 백엔드나 FCM으로부터 메시지를 받았을 때, 화면 하단에 알림 메시지를 담은 `SnackBar`가 즉시 표시되도록 `home_screen.dart` 초기화 로직을 업데이트했습니다.
- **호환성 보정**: 현 타겟 SDK 환경에서 정의되지 않은 `Color.withValues` 메서드를 안전하고 하위 호환성을 가진 `Color.withOpacity` 메서드로 일괄 리팩토링하여 빌드 에러를 방지했습니다.
- **Gradle 빌드 및 SDK/NDK 호환성 확보**:
  - 프로젝트 수준 `settings.gradle.kts`와 앱 수준 `build.gradle.kts`에 `com.google.gms.google-services` 플러그인을 정상 적용하여 Firebase 연동을 완료했습니다.
  - 최신 Firebase 라이브러리 연동 규격에 맞추어 `compileSdk` 버전을 `35`로, `ndkVersion`을 `"27.0.12077973"`으로 최적화했습니다.
  - 에뮬레이터 디버깅 지원을 위해 `abiFilters`에 `"x86_64"`를 추가하고 중복 항목을 정리했습니다.

---

## 🚀 2026.06.13 업데이트: Sprint 2 최종 마일스톤 통합 (온디바이스 AI 모델 및 로깅/전처리 고도화)

### 1. 온디바이스 AI 최신 모델 및 DB 마이그레이션 (P0)
- **MobileCLIP2-S3 FP16 연동**: `assets/mobile_artifacts_fp16/` 경로를 신설하고 이미지/텍스트 인코더 모델 파일들(`.onnx`, `.onnx.data`, `manifest.json`, `prototype_index.json` 등)을 완벽하게 배치했습니다.
- **Android 네이티브 에셋 동적 캐싱**: `MainActivity.kt`에서 `manifest.json`을 파싱하여 동적으로 기기 내부 경로로 모델들을 복사하도록 수정했으며, 파일 크기를 대조하여 모델 업데이트 시 강제 덮어쓰기 캐시 갱신 기능을 탑재했습니다.
- **23-Class 팩트체크 및 데이터 갱신**: classes.json 기준 23개 ID를 검증하고, 이에 맞춰 창경궁/덕수궁 세부 전각 등 12종의 세부 데이터를 보강해 총 25종의 마스터 카탈로그 데이터셋 구축 및 sqlite DB 마이그레이션을 완료했습니다.

### 2. 스코어 이원화 및 UI/UX 개정 (P1)
- **텍스트 검색 분리**: 키워드(LIKE) 검색과 향후 연동할 Semantic 검색을 분리하여 `score_type: "keyword_match"` 형태로 스코어 포맷을 명확히 이원화하여 반환하도록 설계했습니다.
- **유사도 점수 개정**: 정답 확률(%) 오인을 방지하기 위해 다국어 번역 리소스에 `'similarity'`를 신설하고, UI 상의 점수 표기를 **'유사도 75'** 형태로 정수화 표출을 시정했습니다.
- **부모·자식 연동 및 상위 타이틀 결합 표출**: `parent_landmark_id`를 조인하여 **'덕수궁 · 대한문'** 형태로 부모 랜드마크와 세부 전각명이 자연스럽게 결합되어 노출되도록 검색 결과 및 상세 정보 뷰를 고도화했습니다.

### 3. 운영 및 디버깅 품질 향상 (P2)
- **검색 로깅 정보 대폭 확장 (SQLite & 서버 DB)**:
  - 로컬 SQLite DB 스키마 버전 5 승격: `search_logs` 테이블에 `model_version`, `backend`, `top3_scores`, `margin`, `decision_status`, `latency_ms` 필드를 추가했습니다.
  - 서버 DB DDL 및 API 구축: SQLAlchemy `SearchLog` 모델 설계 및 Pydantic 스키마 정의, `POST /api/search/logs` API 추가로 서버 측 DB에도 검색 로그 히스토리가 연동 적재되도록 하였습니다.
  - 모바일 로깅 이원화: 로컬 SQLite 저장과 백엔드 서버 로깅 API 전송(백그라운드 비동기)을 이원화 처리했습니다.
- **전처리 상수 동적 파싱**: `mean`, `std`, `image_size` 상수를 하드코딩 `static const` 대신 에셋 내 `preprocessing.json` 파일에서 로딩 시점에 동적으로 파싱 및 적용되도록 코드를 전면 개편했습니다.
- **앱 시작 시 모델 사양 정합성 검증 및 개발자 경고 알림 탑재**: 
  - 앱 최초 구동 시 백그라운드로 `manifest.json` 사양(ID, 정밀도, 클래스 수)을 기대 사양과 대조하여 `modelSpecWarning` 경고를 식별합니다.
  - 스펙 Mismatch가 감지되면 `HomeScreen` 최초 진입 시 개발자에게 **AlertDialog 경고 팝업**을 즉각 노출해 주는 강력한 안전 장치를 연동하였습니다.
- **정적 컴파일 검증**: `analysis_options.yaml`에서 emulate 폴더를 격리하여 빌드와 무관한 외부 에러들을 배제하고 linter 경고를 클리어하여 `flutter analyze` 100% 무결 통과를 확보했습니다.

---


## 🚀 2026.06.12 업데이트: 건의 상태 변경 알림 트리거 및 앱 내 알림함 API 구축

### 1. 백엔드 (FastAPI) 변경 사항
- **실시간 알림 발송 로직 연동**: 관리자 권한으로 건의 상태가 변경(`approved` 또는 `rejected`)되는 순간, 해당 유저의 디바이스 토큰(`push_token`)을 조회하여 실시간 FCM 푸시 알림을 즉시 발송합니다.
- **알림 내역 데이터베이스 테이블 (`Notification`)**: 알림 이력을 기록 및 저장할 수 있도록 `Notification` 테이블을 설계하고 추가했습니다. (유저 탈퇴 시 연동된 알림 데이터는 cascade delete 처리)
- **앱 내 알림함 API**:
  - `GET /api/notifications`: 로그인한 사용자의 모든 알림 목록을 최신순으로 조회합니다.
  - `PATCH /api/notifications/{notification_id}/read`: 본인이 수신한 특정 알림을 읽음(`is_read = true`) 처리합니다.
- **통합 시나리오 검증 성공**: FastAPI `TestClient` 기반 통합 시나리오 테스트(로그인 -> 건의 제출 -> 관리자 승인 -> 알림 DB 생성 확인 -> 알림 조회 API 및 읽음 처리 상태 갱신 API 호출)를 전 단계 모두 성공적으로 완료했습니다.

---

## 🛠️ 팀원 연동 및 로컬 테스트 가이드

### 1. Firebase 콘솔 설정 (실제 FCM 수신용)
FCM을 실제 모바일 기기 혹은 에뮬레이터에서 수신하기 위해 콘솔 설정을 진행해야 합니다:
1. **[Firebase 콘솔](https://console.firebase.google.com/)**에 접속하여 새 프로젝트를 생성합니다.
2. **Android 앱 추가**: 패키지명 `com.example.landmark_demo_app` 등으로 등록 후 `google-services.json` 파일을 다운로드하여 `android/app/` 경로에 배치합니다.
3. **iOS 앱 추가**: 번들 ID 등록 후 `GoogleService-Info.plist` 파일을 다운로드하여 `ios/Runner/` 경로에 배치합니다.
4. **서비스 계정 키 발급**: `프로젝트 설정` -> `서비스 계정` 탭에서 **새 비공개 키 생성** 버튼을 눌러 JSON 파일을 다운로드합니다. 이 파일의 이름을 `firebase-service-account.json`으로 변경한 뒤 `backend/` 폴더 바로 아래에 넣어주세요.

### 2. 백엔드 로컬 실행 방법
```bash
# 의존성 패키지 설치
cd backend
pip install -r requirements.txt

# 데이터 마스터 마이그레이션 (25종 랜드마크 적재 및 search_logs 테이블 DDL 생성)
.\.venv\Scripts\python.exe migrate_landmarks.py

# uvicorn 서버 구동 (기본 포트 8000, 실기기 연동을 위해 0.0.0.0 바인딩 권장)
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. 클라이언트 로컬 실행 방법 (에뮬레이터 & 실기기)
* **Android 에뮬레이터에서 실행할 경우**:
  ```bash
  flutter run
  ```
  *(에뮬레이터 환경에서는 기본적으로 `http://10.0.2.2:8000` 호스트 게이트웨이로 서버에 접속합니다.)*

* **실제 Android 스마트폰 기기에서 실행할 경우 (추천 ⭐)**:
  실기기에서는 에뮬레이터용 가상 IP(`10.0.2.2`)가 동작하지 않으므로, **포트 역포워딩(ADB Reverse)** 설정을 통해 USB 디버깅 통로로 PC 백엔드에 신호를 넘겨주어야 합니다.
  1. PC의 PowerShell 창에서 아래 명령어로 8000번 포트 터널을 개방합니다:
     ```powershell
     & C:\Users\user\AppData\Local\Android\Sdk\platform-tools\adb.exe reverse tcp:8000 tcp:8000
     ```
  2. 다음 명령어로 `localhost` 주소를 명시적으로 주입하며 앱을 실행합니다:
     ```bash
     flutter run --dart-define=BACKEND_URL=http://localhost:8000
     ```
  *(실제 기기 빌드 시 `ArgMax(13)` 노드 결핍으로 인한 모델 로딩 실패를 차단하기 위해 `onnxruntime-android:1.16.0` Full 바이너리가 자동으로 컴파일 패키징됩니다.)*

### 4. 관리자(Admin) 계정 승격 및 관리자 페이지 테스트 방법
앱 내의 건의 관리 및 승인/반려 시 실시간 푸시 발송 트리거를 테스트하려면 관리자 계정이 필요합니다.
1. 스마트폰 앱에서 사용하려는 이메일 주소(예: `admin@test.com`)로 **회원가입**을 진행합니다.
2. 가입에 성공하면, PC 터미널에서 다음 스크립트를 실행해 데이터베이스 상에서 해당 계정을 즉시 관리자로 승격시킵니다:
   ```powershell
   # 가입된 이메일을 승격 (기본 이메일: admin@test.com)
   .\.venv\Scripts\python.exe C:\Users\user\.gemini\antigravity\brain\456de5ea-3e27-41c1-96fd-506187831536\scratch\promote_admin.py

   # 만약 임의의 다른 이메일(예: your_email@domain.com)로 가입하여 승격하고 싶다면 이메일 기재
   .\.venv\Scripts\python.exe C:\Users\user\.gemini\antigravity\brain\456de5ea-3e27-41c1-96fd-506187831536\scratch\promote_admin.py your_email@domain.com
   ```
3. 승격 완료 후 해당 이메일로 앱에 다시 로그인하면 메인 화면 우측 상단에 **관리자 기능(톱니바퀴 등) 진입 아이콘**이 생기며, 유저들이 등록한 건의 목록을 조회하고 승인/반려 처리를 수행할 수 있습니다.

### 5. Sprint 2 백엔드 및 DB 주요 변경 사항
* **검색 로그 테이블 스키마 구축 (`search_logs`)**:
  * 모바일 로컬 SQLite 및 서버 DB에 검색 이력에 관한 디버깅 확장 필드(`model_version`, `backend`, `top3_scores`, `margin`, `decision_status`, `latency_ms`)가 동일하게 설계되어 적재됩니다.
* **검색 로그 수집 API 추가**:
  * `POST /api/search/logs`: 모바일 앱에서 검색 성공/실패 시 비동기 백그라운드 요청을 통해 서버 데이터베이스에도 상세한 검색 로그 정보를 자동 업로드 및 수집합니다.