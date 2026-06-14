import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class TextIndexItem {
  final String textId;
  final String landmarkId;
  final String? parentLandmarkId;
  final String language;
  final String textType;
  final String text;
  final double weight;
  final List<double> embedding;

  const TextIndexItem({
    required this.textId,
    required this.landmarkId,
    required this.parentLandmarkId,
    required this.language,
    required this.textType,
    required this.text,
    required this.weight,
    required this.embedding,
  });
}

class TextIndexRepository {
  static const String _assetPath =
      'assets/mobile_artifacts_fp16/text_index.json';

  List<TextIndexItem>? _items;

  Future<List<TextIndexItem>> loadItems() async {
    if (_items != null) return _items!;
    final raw = await rootBundle.loadString(_assetPath);
    final jsonMap = json.decode(raw) as Map<String, dynamic>;
    final items = (jsonMap['items'] as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return TextIndexItem(
        textId: map['text_id'] as String,
        landmarkId: map['landmark_id'] as String,
        parentLandmarkId: map['parent_landmark_id'] as String?,
        language: map['language'] as String,
        textType: map['text_type'] as String,
        text: map['text'] as String,
        weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
        embedding: _l2Normalize(
          (map['embedding'] as List<dynamic>)
              .map((value) => (value as num).toDouble())
              .toList(),
        ),
      );
    }).toList();
    _items = items;
    return items;
  }

  static List<double> _l2Normalize(List<double> values) {
    var norm = 0.0;
    for (final value in values) {
      norm += value * value;
    }
    norm = sqrt(norm);
    if (norm < 1e-12) return values;
    return values.map((value) => value / norm).toList();
  }
}
