import 'package:sqflite/sqflite.dart';

class KeywordSearchService {
  Future<Map<String, double>> scoreLandmarks(Database db, String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return {};
    final likeQuery = '%$trimmed%';
    final rows = await db.rawQuery('''
      SELECT l.id as landmark_id, l.name_ko, l.name_en, c.candidate_text
      FROM landmarks l
      LEFT JOIN candidate_texts c ON l.id = c.landmark_id
      WHERE lower(l.name_ko) LIKE ?
         OR ? LIKE '%' || lower(l.name_ko) || '%'
         OR lower(l.name_en) LIKE ?
         OR ? LIKE '%' || lower(l.name_en) || '%'
         OR lower(c.candidate_text) LIKE ?
         OR ? LIKE '%' || lower(c.candidate_text) || '%'
    ''', [
      likeQuery,
      trimmed,
      likeQuery,
      trimmed,
      likeQuery,
      trimmed,
    ]);
    final scores = <String, double>{};
    for (final row in rows) {
      final landmarkId = row['landmark_id'] as String;
      final candidates = [
        _TextCandidate(row['name_ko']?.toString() ?? '', 1.0),
        _TextCandidate(row['name_en']?.toString() ?? '', 1.0),
        _TextCandidate(row['candidate_text']?.toString() ?? '', 0.95),
      ];
      var best = scores[landmarkId] ?? 0.0;
      for (final candidate in candidates) {
        final text = candidate.text.trim().toLowerCase();
        if (text.isEmpty) continue;
        if (trimmed == text) {
          best = best < candidate.exactScore ? candidate.exactScore : best;
        } else if (text.contains(trimmed) || trimmed.contains(text)) {
          best = best < 0.6 ? 0.6 : best;
        }
      }
      if (best > 0) {
        scores[landmarkId] = best;
      }
    }
    return scores;
  }
}

class _TextCandidate {
  final String text;
  final double exactScore;

  const _TextCandidate(this.text, this.exactScore);
}
