import 'package:flutter/material.dart';

import 'api/local_api_client_impl.dart';
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

  runApp(LandmarkApp(apiClient: apiClient));
}

class LandmarkApp extends StatelessWidget {
  final LocalApiClientImpl apiClient;

  const LandmarkApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seoul Landmark Assistant',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: HomeScreen(apiClient: apiClient),
    );
  }
}
