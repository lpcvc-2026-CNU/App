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

# 데이터 마스터 마이그레이션 (SQLite/MySQL에 랜드마크 적재)
python migrate_landmarks.py

# uvicorn 서버 구동 (기본 포트 8000)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. 클라이언트 로컬 실행 방법
```bash
# Flutter 패키지 가져오기
flutter pub get

# 앱 실행 (FCM 토큰은 앱 실행 시 터미널 콘솔창 로그에 [FCM 디버그] 태그로 출력됩니다)
flutter run
```