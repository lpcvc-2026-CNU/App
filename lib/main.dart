import 'package:flutter/material.dart';

import 'api/backend_client.dart';
import 'api/local_api_client_impl.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_guard.dart';
import 'auth/auth_scope.dart';
import 'auth/token_storage.dart';
import 'data/database_helper.dart';
import 'data/landmark_repository.dart';
import 'data/suggestion_repository.dart';
import 'services/image_quality_service.dart';
import 'services/onnx_inference_service.dart';
import 'services/push_notification_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [김규현] FCM 푸시 알림 인프라 초기화.
  // Firebase 설정 파일이 없으면 Mock Sandbox 모드로 자동 전환됨.
  await PushNotificationService.instance.initialize();

  await DatabaseHelper.instance.database;
  try {
    await DatabaseHelper.instance.populateInitialData();
  } catch (e) {
    print('Initial data population failed: $e');
  }

  final onnxService = OnnxInferenceService();
  final qualityService = ImageQualityService();
  final dbHelper = DatabaseHelper.instance;
  final apiClient = LocalApiClientImpl(onnxService, qualityService, dbHelper);

  // [금동엽] 인증: 보안 저장소 기반 토큰 보관 + 전역 컨트롤러.
  final tokenStorage = SecureTokenStorage();
  // BackendClient를 AuthController와 공유해 로그인/건의 API 모두에서 재사용.
  final backendClient = BackendClient(tokenStorage: tokenStorage);
  final authController = AuthController(
    storage: tokenStorage,
    backendClient: backendClient,
  );
  // 저장된 토큰을 확인해 로그인 상태를 복원.
  await authController.bootstrap();

  // [김규현] 건의 API 연동: 랜드마크 캐시 + 건의 레포.
  final landmarkRepository = LandmarkRepository(backendClient);
  final suggestionRepository = ApiSuggestionRepository(
    client: backendClient,
    landmarks: landmarkRepository,
  );

  runApp(LandmarkApp(
    apiClient: apiClient,
    authController: authController,
    suggestionRepository: suggestionRepository,
  ));
}

class LandmarkApp extends StatelessWidget {
  final LocalApiClientImpl apiClient;
  final AuthController authController;
  final SuggestionRepository suggestionRepository;

  const LandmarkApp({
    super.key,
    required this.apiClient,
    required this.authController,
    required this.suggestionRepository,
  });

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: authController,
      child: MaterialApp(
        title: 'Seoul Landmark Assistant',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        // [금동엽] 로그인 여부에 따라 로그인 화면 ↔ 홈 화면을 자동 분기.
        home: AuthGuard(
          child: HomeScreen(
            apiClient: apiClient,
            suggestionRepository: suggestionRepository,
          ),
        ),
      ),
    );
  }
}
