import 'package:flutter/material.dart';

import 'api/local_api_client_impl.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_guard.dart';
import 'auth/auth_scope.dart';
import 'auth/token_storage.dart';
import 'data/database_helper.dart';
import 'services/image_quality_service.dart';
import 'services/onnx_inference_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 인증: 보안 저장소 기반 토큰 보관 + 전역 컨트롤러.
  final authController = AuthController(storage: SecureTokenStorage());
  // 저장된 토큰을 확인해 로그인 상태를 복원.
  await authController.bootstrap();

  runApp(LandmarkApp(apiClient: apiClient, authController: authController));
}

class LandmarkApp extends StatelessWidget {
  final LocalApiClientImpl apiClient;
  final AuthController authController;

  const LandmarkApp({
    super.key,
    required this.apiClient,
    required this.authController,
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
        // 로그인 여부에 따라 로그인 화면 ↔ 홈 화면을 자동 분기.
        home: AuthGuard(child: HomeScreen(apiClient: apiClient)),
      ),
    );
  }
}
