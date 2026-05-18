import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  Database? _db;

  Database get db {
    if (_db == null) throw StateError('LocalDb no inicializado. Llama open()');
    return _db!;
  }

  Future<void> open() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'agromag.db');

    _db = await openDatabase(
      fullPath,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT NOT NULL,
        municipality TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT NOT NULL,
        pending_update INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE auth_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        last_user_id TEXT,
        last_email TEXT,
        last_sync_at TEXT
      )
    ''');

    await _createCropsTable(db);
    await _createWeatherCacheTable(db);
    await _createCropEventsTable(db);
    await _createPendingDecisionsTable(db);
    await _createRecommendationsCacheTable(db);
    await _createRecommendationParamsCacheTable(db);
  }

  static Future<void> _createCropsTable(Database db) async {
    await db.execute('''
      CREATE TABLE crops (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        crop_type TEXT NOT NULL,
        area_hectares REAL NOT NULL,
        municipality TEXT NOT NULL,
        sown_date TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        pending_delete INTEGER NOT NULL DEFAULT 0,
        is_new_local INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_crops_profile ON crops(profile_id)');
    await db.execute('CREATE INDEX idx_crops_sync ON crops(sync_status)');
  }

  static Future<void> _createWeatherCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE weather_cache (
        municipality TEXT PRIMARY KEY,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        fetched_at TEXT NOT NULL,
        forecast_json TEXT
      )
    ''');
  }

  static Future<void> _createCropEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE crop_events (
        id TEXT PRIMARY KEY,
        crop_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        notes TEXT,
        quantity REAL,
        unit TEXT,
        event_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        pending_delete INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_events_crop ON crop_events(crop_id)');
    await db.execute(
      'CREATE INDEX idx_events_pending_delete ON crop_events(pending_delete)',
    );
  }

  static Future<void> _createPendingDecisionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE pending_decisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recommendation_id TEXT NOT NULL,
        followed INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pending_decisions_rec ON pending_decisions(recommendation_id)',
    );
  }

  static Future<void> _createRecommendationsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE recommendations_cache (
        id TEXT PRIMARY KEY,
        crop_id TEXT NOT NULL,
        type TEXT,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'RULE_LOCAL',
        generated_at TEXT NOT NULL,
        crop_type TEXT,
        followed INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_rec_cache_crop ON recommendations_cache(crop_id)',
    );
    await db.execute(
      'CREATE INDEX idx_rec_cache_followed ON recommendations_cache(followed)',
    );
  }

  static Future<void> _createRecommendationParamsCacheTable(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE recommendation_params_cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createCropsTable(db);
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'profile',
        'pending_update',
        'INTEGER NOT NULL DEFAULT 0',
      );

      await _addColumnIfMissing(
        db,
        'crops',
        'pending_delete',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'crops',
        'is_new_local',
        'INTEGER NOT NULL DEFAULT 0',
      );

      await _createWeatherCacheTable(db);
      await _createCropEventsTable(db);
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'weather_cache', 'forecast_json', 'TEXT');
    }
    if (oldVersion < 5) {
      await _createPendingDecisionsTable(db);
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        'crop_events',
        'pending_delete',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_pending_delete ON crop_events(pending_delete)',
      );
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(db, 'crop_events', 'quantity', 'REAL');
      await _addColumnIfMissing(db, 'crop_events', 'unit', 'TEXT');
    }
    if (oldVersion < 8) {
      await _createRecommendationsCacheTable(db);
    }
    if (oldVersion < 9) {
      await _createRecommendationParamsCacheTable(db);
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> clearUserData() async {
    final db = _db;
    if (db == null) return;
    await db.delete('crops');
    await db.delete('profile');
    await db.delete('weather_cache');
    await db.delete('crop_events');
    await db.delete('auth_state');
    await db.delete('pending_decisions');
    await db.delete('recommendations_cache');
    await db.delete('recommendation_params_cache');
  }

  Future<void> purgeOldSyncedData() async {
    final db = _db;
    if (db == null) return;

    final now = DateTime.now();
    final thirtyDaysAgo = now
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final twentyFourHoursAgo = now
        .subtract(const Duration(hours: 24))
        .toIso8601String();

    // Los tombstones evitan que un pull reviva cultivos borrados localmente.
    // No se purgan automáticamente hasta tener confirmación remota explícita.

    await db.rawDelete(
      'DELETE FROM crop_events WHERE synced = 1 AND event_date < ?',
      [thirtyDaysAgo],
    );

    await db.rawDelete('DELETE FROM weather_cache WHERE fetched_at < ?', [
      twentyFourHoursAgo,
    ]);
  }
}
