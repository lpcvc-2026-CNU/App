import 'package:flutter_test/flutter_test.dart';
import 'package:landmark_demo_app/api/local_api_client_impl.dart';
import 'package:landmark_demo_app/data/database_helper.dart';
import 'package:landmark_demo_app/services/image_quality_service.dart';
import 'package:landmark_demo_app/services/onnx_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LocalApiClientImpl makeClient() {
    return LocalApiClientImpl(
      OnnxInferenceService(),
      ImageQualityService(),
      DatabaseHelper.instance,
    );
  }

  test('confidence policy marks high cosine and margin as matched', () async {
    final client = makeClient();

    final result = await client.checkSearchConfidence([
      {'landmark_id': 'gwanghwamun', 'raw_score': 0.50},
      {'landmark_id': 'naksan_park', 'raw_score': 0.20},
      {'landmark_id': 'cheonggyecheon', 'raw_score': 0.10},
    ], 'image');

    expect(result['decision'], 'matched');
    expect(result['margin'], closeTo(0.30, 1e-9));
    expect(result['reason_codes'], contains('top1_high'));
  });

  test('confidence policy keeps close top scores ambiguous', () async {
    final client = makeClient();

    final result = await client.checkSearchConfidence([
      {'landmark_id': 'gwanghwamun', 'raw_score': 0.40},
      {'landmark_id': 'gyeongbokgung_geunjeongmun', 'raw_score': 0.35},
      {'landmark_id': 'gyeongbokgung_geunjeongjeon', 'raw_score': 0.30},
    ], 'image');

    expect(result['decision'], 'ambiguous');
    expect(result['reason_codes'], contains('margin_low'));
  });
}
