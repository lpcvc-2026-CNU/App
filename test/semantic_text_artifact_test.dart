import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landmark_demo_app/data/text_index_repository.dart';
import 'package:landmark_demo_app/services/tokenizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tokenizer matches exported OpenCLIP fixture tokens', () async {
    final raw = await rootBundle.loadString(
      'assets/mobile_artifacts_fp16/tokenizer_bundle.json',
    );
    final bundle = json.decode(raw) as Map<String, dynamic>;
    final fixtures = bundle['fixtures'] as List<dynamic>;
    final tokenizer = TokenizerService();

    expect(bundle['context_length'], 77);
    expect(fixtures, isNotEmpty);

    for (final fixture in fixtures) {
      final row = fixture as Map<String, dynamic>;
      final expected = (row['tokens'] as List<dynamic>)
          .map((value) => (value as num).toInt())
          .toList();
      final actual = await tokenizer.tokenize(row['text'] as String);

      expect(actual, expected, reason: "fixture=${row['text']}");
    }
  });

  test('text index loads normalized 512d embeddings for semantic search',
      () async {
    final repository = TextIndexRepository();
    final items = await repository.loadItems();

    expect(items, isNotEmpty);
    expect(items.any((item) => item.landmarkId == 'gwanghwamun'), isTrue);

    for (final item in items.take(20)) {
      expect(item.embedding.length, 512);
      final norm = sqrt(
        item.embedding.fold<double>(
          0.0,
          (sum, value) => sum + value * value,
        ),
      );
      expect(norm, closeTo(1.0, 1e-4), reason: item.textId);
    }
  });
}
