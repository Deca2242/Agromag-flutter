import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton que gestiona la base de datos SQLite de la app.
///
/// Versiones y migraciones:
///   v1 — tablas `profile` y `auth_state`.
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
      version: 1,
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
        synced_at TEXT NOT NULL
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
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migraciones futuras van aquí con bloques if (oldVersion < X).
  }
}
