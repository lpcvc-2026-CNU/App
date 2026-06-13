import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('landmark_assistant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Landmarks 테이블: 다국어 및 parent_landmark_id 컬럼 추가
    await db.execute('''
      CREATE TABLE landmarks (
        id TEXT PRIMARY KEY,
        name_ko TEXT NOT NULL,
        name_en TEXT NOT NULL,
        name_zh TEXT NOT NULL,
        name_ja TEXT NOT NULL,
        district TEXT,
        description_ko TEXT,
        description_en TEXT,
        description_zh TEXT,
        description_ja TEXT,
        latitude REAL CHECK (latitude >= -90.0 AND latitude <= 90.0),
        longitude REAL CHECK (longitude >= -180.0 AND longitude <= 180.0),
        parent_landmark_id TEXT,
        UNIQUE(name_ko, district)
      )
    ''');

    // Candidate_Texts 테이블: 다국어 지원 및 중복 방지
    await db.execute('''
      CREATE TABLE candidate_texts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        landmark_id TEXT NOT NULL,
        candidate_text TEXT NOT NULL,
        language TEXT NOT NULL,
        FOREIGN KEY (landmark_id) REFERENCES landmarks (id),
        UNIQUE(landmark_id, candidate_text, language)
      )
    ''');

    // Search_Logs 테이블: P2 디버깅 로그 필드 대폭 확장
    await db.execute('''
      CREATE TABLE search_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        query_type TEXT NOT NULL,
        top1_id TEXT,
        decision TEXT,
        reason_codes TEXT,
        latency_ms INTEGER,
        model_version TEXT,
        backend TEXT,
        top3_scores TEXT,
        margin REAL,
        decision_status TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS candidate_texts');
      await db.execute('DROP TABLE IF EXISTS landmarks');
      await db.execute('DROP TABLE IF EXISTS search_logs');
      await _createDB(db, newVersion);
    }
  }

  /// JSON 주소 필드 또는 설명에서 '구(District)' 추출
  String _extractDistrict(Map<String, dynamic> item) {
    // 1. address 필드가 있을 경우 우선 탐색
    final address = item['address'] as String?;
    if (address != null && address.isNotEmpty) {
      final match = RegExp(r'([가-힣]+구)').firstMatch(address);
      if (match != null) return match.group(1)!;
    }
    
    // 2. address가 없다면 description_ko에서 탐색 (Fallback)
    final desc = item['description_ko'] as String?;
    if (desc != null && desc.isNotEmpty) {
      final match = RegExp(r'([가-힣]+구)').firstMatch(desc);
      if (match != null) return match.group(1)!;
    }
    
    return '알수없음';
  }

  /// 앱 초기화 시 landmark_info.json을 파싱하여 DB에 저장
  Future<void> populateInitialData() async {
    final db = await instance.database;
    
    // 기존 데이터 존재 여부 확인
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM landmarks'));
    if (count != null && count > 0) return;

    final String jsonString = await rootBundle.loadString('assets/landmark_info.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> items = jsonMap['items'];

    Batch batch = db.batch();

    for (var item in items) {
      final district = _extractDistrict(item);

      batch.insert('landmarks', {
        'id': item['landmark_id'],
        'name_ko': item['name_ko'],
        'name_en': item['name_en'],
        'name_zh': item['name_zh'],
        'name_ja': item['name_ja'],
        'district': district,
        'description_ko': item['description_ko'],
        'description_en': item['description_en'],
        'description_zh': item['description_zh'],
        'description_ja': item['description_ja'],
        'latitude': item['latitude'],
        'longitude': item['longitude'],
        'parent_landmark_id': item['parent_landmark_id'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      
      // Alias를 candidate_texts로 등록
      final aliases = item['aliases'] as List<dynamic>? ?? [];
      for (var alias in aliases) {
        batch.insert('candidate_texts', {
          'landmark_id': item['landmark_id'],
          'candidate_text': alias.toString(),
          'language': 'ko',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await batch.commit(noResult: true);
  }
}
