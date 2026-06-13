import 'dart:convert';

import 'package:flutter/services.dart';

class TokenizerService {
  static const String _assetPath =
      'assets/mobile_artifacts_fp16/tokenizer_bundle.json';

  Map<String, dynamic>? _bundle;
  Map<int, String>? _byteEncoder;
  Map<String, int>? _encoder;
  Map<String, int>? _mergeRanks;
  final Map<String, String> _cache = {};

  Future<List<int>> tokenize(String text) async {
    await _load();
    final bundle = _bundle!;
    final contextLength = bundle['context_length'] as int;
    final sot = bundle['sot_token_id'] as int;
    final eot = bundle['eot_token_id'] as int;
    final tokens = <int>[sot, ..._encode(text), eot];
    if (tokens.length > contextLength) {
      return tokens.take(contextLength).toList()..[contextLength - 1] = eot;
    }
    return [...tokens, ...List<int>.filled(contextLength - tokens.length, 0)];
  }

  Future<void> _load() async {
    if (_bundle != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final bundle = json.decode(raw) as Map<String, dynamic>;
    _bundle = bundle;
    _byteEncoder = (bundle['byte_encoder'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(int.parse(key), value as String),
    );
    _encoder = (bundle['encoder'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
    _mergeRanks = {
      for (final row in bundle['merges'] as List<dynamic>)
        '${row['first']} ${row['second']}': (row['rank'] as num).toInt(),
    };
    _cache
      ..clear()
      ..['<start_of_text>'] = '<start_of_text>'
      ..['<end_of_text>'] = '<end_of_text>';
  }

  List<int> _encode(String text) {
    final cleanText = _clean(text);
    final pattern = RegExp(
      r"'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+",
      caseSensitive: false,
      unicode: true,
    );
    final tokens = <int>[];
    for (final match in pattern.allMatches(cleanText)) {
      final token = match.group(0);
      if (token == null || token.isEmpty) continue;
      final byteEncoded =
          utf8.encode(token).map((byte) => _byteEncoder![byte]!).join();
      for (final bpeToken in _bpe(byteEncoded).split(' ')) {
        tokens.add(_encoder![bpeToken]!);
      }
    }
    return tokens;
  }

  String _clean(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _bpe(String token) {
    final cached = _cache[token];
    if (cached != null) return cached;
    final chars = token.runes.map(String.fromCharCode).toList();
    if (chars.isEmpty) return token;
    var word = <String>[
      ...chars.take(chars.length - 1),
      '${chars.last}</w>',
    ];
    var pairs = _getPairs(word);
    if (pairs.isEmpty) return '$token</w>';

    while (true) {
      String? bestPair;
      var bestRank = 1 << 62;
      for (final pair in pairs) {
        final rank = _mergeRanks![pair];
        if (rank != null && rank < bestRank) {
          bestPair = pair;
          bestRank = rank;
        }
      }
      if (bestPair == null) break;
      final parts = bestPair.split(' ');
      final first = parts[0];
      final second = parts[1];
      final newWord = <String>[];
      var i = 0;
      while (i < word.length) {
        var j = word.indexOf(first, i);
        if (j == -1) {
          newWord.addAll(word.sublist(i));
          break;
        }
        newWord.addAll(word.sublist(i, j));
        i = j;
        if (i < word.length - 1 && word[i] == first && word[i + 1] == second) {
          newWord.add(first + second);
          i += 2;
        } else {
          newWord.add(word[i]);
          i += 1;
        }
      }
      word = newWord;
      if (word.length == 1) break;
      pairs = _getPairs(word);
    }
    final result = word.join(' ');
    _cache[token] = result;
    return result;
  }

  Set<String> _getPairs(List<String> word) {
    final pairs = <String>{};
    if (word.length < 2) return pairs;
    for (var i = 0; i < word.length - 1; i++) {
      pairs.add('${word[i]} ${word[i + 1]}');
    }
    return pairs;
  }
}
