import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton que gestiona la base de datos SQLite de la app.
///
/// Versiones y migraciones:
///   v1 — tablas `profile` y `auth_state`.
///   v2 — tabla `crops` con offline-first sync queue.
///   v3 — columnas pending_update/pending_delete/is_new_local,
///         tablas `weather_cache` y `crop_events`.
///   v4 — columna opcional `forecast_json` en `weather_cache` (pronóstico JSON;
///         alinea BD si antes hubo una build con user_version 4).
///   v5 — tabla `pending_decisions` para decisiones de recomendaciones offline.
///   v6 — columna `pending_delete` en `crop_events` para eliminación offline.
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
      version: 6,
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

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createCropsTable(db);
    }
    if (oldVersion < 3) {
      // profile: add pending_update
      try {
        await db.execute(
          'ALTER TABLE profile ADD COLUMN pending_update INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}

      // crops: add pending_delete and is_new_local
      try {
        await db.execute(
          'ALTER TABLE crops ADD COLUMN pending_delete INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        // Existing crops were synced (came from server) so is_new_local=0
        await db.execute(
          'ALTER TABLE crops ADD COLUMN is_new_local INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}

      await _createWeatherCacheTable(db);
      await _createCropEventsTable(db);
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE weather_cache ADD COLUMN forecast_json TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await _createPendingDecisionsTable(db);
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE crop_events ADD COLUMN pending_delete INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX idx_events_pending_delete ON crop_events(pending_delete)',
        );
      } catch (_) {}
    }
  }

  /// Borra todos los datos del usuario para logout limpio.
  Future<void> clearUserData() async {
    final db = _db;
    if (db == null) return;
    await db.delete('crops');
    await db.delete('profile');
    await db.delete('weather_cache');
    await db.delete('crop_events');
    await db.delete('auth_state');
    await db.delete('pending_decisions');
  }

  /// Limpia datos antiguos ya sincronizados para evitar crecimiento indefinido de la BD.
  ///
  /// Reglas de purga:
  ///   - crops con pending_delete=1 → borrado físico (ya confirmados por servidor).
  ///   - crop_events con synced=1 y older than 30 días → se pueden re-descargar.
  ///   - weather_cache con fetched_at older than 24h → se refresca automáticamente.
  ///   - pending_decisions → NO se purgan aquí (se borran tras sync exitoso).
  ///
  /// Debe llamarse tras un sync exitoso (isFullSuccess).
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

    // 1. Cultivos marcados para borrar (ya sincronizados con servidor)
    await db.delete('crops', where: 'pending_delete = 1');

    // 2. Eventos sincronizados older than 30 días
    await db.rawDelete(
      'DELETE FROM crop_events WHERE synced = 1 AND event_date < ?',
      [thirtyDaysAgo],
    );

    // 3. Weather cache older than 24h
    await db.rawDelete('DELETE FROM weather_cache WHERE fetched_at < ?', [
      twentyFourHoursAgo,
    ]);
  }
}
