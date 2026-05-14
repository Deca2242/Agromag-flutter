import 'package:sqflite/sqflite.dart';

import '../../domain/models/crop.dart';
import '../../domain/models/crop_type.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/sync_status.dart';
import 'local_db.dart';

/// Acceso a la tabla `crops` en SQLite.
class CropsLocalDao {
  const CropsLocalDao();

  static const _table = 'crops';

  Future<void> insert(Crop crop, {required String profileId}) async {
    final db = LocalDb.instance.db;
    await db.insert(_table, _toRow(crop, profileId));
  }

  Future<List<Crop>> listByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'profile_id = ? AND pending_delete = 0',
      whereArgs: [profileId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Crop?> findById(String id) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<Crop>> pendingByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'profile_id = ? AND sync_status = ? AND pending_delete = 0',
      whereArgs: [profileId, SyncStatus.PENDING.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Returns ids of crops pending upload to server for the first time (is_new_local=1).
  Future<List<Crop>> newLocalPendingByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 1 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.PENDING.name],
    );
    return rows.map(_fromRow).toList();
  }

  /// Returns crops that were edited offline (already on server, pending re-upload).
  Future<List<Crop>> editedPendingByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 0 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.PENDING.name],
    );
    return rows.map(_fromRow).toList();
  }

  /// Nuevos locales cuyo último intento de subida falló (`ERROR`).
  Future<List<Crop>> newLocalErrorByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 1 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.ERROR.name],
    );
    return rows.map(_fromRow).toList();
  }

  /// Ediciones cuyo último intento de subida falló (`ERROR`).
  Future<List<Crop>> editedErrorByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 0 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.ERROR.name],
    );
    return rows.map(_fromRow).toList();
  }

  /// Filas en `ERROR` sin borrado pendente (para badge de sync).
  Future<int> countErrorByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE profile_id = ? AND sync_status = ? AND pending_delete = 0',
      [profileId, SyncStatus.ERROR.name],
    );
    if (rows.isEmpty) return 0;
    final n = rows.first['c'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return 0;
  }

  /// Returns crops pending deletion on the server.
  Future<List<Crop>> pendingDeletesByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'profile_id = ? AND pending_delete = 1',
      whereArgs: [profileId],
    );
    return rows.map(_fromRow).toList();
  }

  /// Marks a crop as pending deletion (hides from UI; deletes from server on reconnect).
  Future<void> markDeletedPending(String id) async {
    final db = LocalDb.instance.db;
    await db.update(
      _table,
      {'pending_delete': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Physically removes a crop row from SQLite.
  Future<void> deleteLocal(String id) async {
    final db = LocalDb.instance.db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = LocalDb.instance.db;
    final now = DateTime.now().toIso8601String();
    final placeholders = ids.map((_) => '?').join(', ');
    await db.rawUpdate(
      'UPDATE $_table SET sync_status = ?, updated_at = ? WHERE id IN ($placeholders)',
      [SyncStatus.SYNCED.name, now, ...ids],
    );
  }

  Future<void> markError(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = LocalDb.instance.db;
    final now = DateTime.now().toIso8601String();
    final placeholders = ids.map((_) => '?').join(', ');
    await db.rawUpdate(
      'UPDATE $_table SET sync_status = ?, updated_at = ? WHERE id IN ($placeholders)',
      [SyncStatus.ERROR.name, now, ...ids],
    );
  }

  /// Upsert de cultivos recibidos del servidor — syncStatus siempre SYNCED,
  /// is_new_local=0 (ya existe en el servidor).
  Future<void> upsertFromServer(
    List<Crop> crops, {
    required String profileId,
  }) async {
    if (crops.isEmpty) return;
    final db = LocalDb.instance.db;
    final batch = db.batch();
    for (final crop in crops) {
      batch.insert(
        _table,
        _toRow(crop, profileId, isNewLocal: false),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Updates an existing crop row keeping is_new_local as-is.
  Future<void> updateCrop(Crop crop) async {
    final db = LocalDb.instance.db;
    await db.update(
      _table,
      {
        'crop_type': crop.cropType.name,
        'area_hectares': crop.areaHectares,
        'municipality': crop.municipality.name,
        'sown_date': _dateStr(crop.sownDate),
        'sync_status': crop.syncStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
        'pending_delete': 0,
      },
      where: 'id = ?',
      whereArgs: [crop.id],
    );
  }

  static Map<String, dynamic> _toRow(
    Crop crop,
    String profileId, {
    bool isNewLocal = true,
  }) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': crop.id,
      'profile_id': profileId,
      'crop_type': crop.cropType.name,
      'area_hectares': crop.areaHectares,
      'municipality': crop.municipality.name,
      'sown_date': _dateStr(crop.sownDate),
      'sync_status': crop.syncStatus.name,
      'created_at': crop.createdAt.toIso8601String(),
      'updated_at': now,
      'pending_delete': 0,
      'is_new_local': isNewLocal ? 1 : 0,
    };
  }

  static Crop _fromRow(Map<String, dynamic> row) {
    return Crop(
      id: row['id'] as String,
      cropType: CropType.fromJson(row['crop_type'] as String),
      areaHectares: (row['area_hectares'] as num).toDouble(),
      municipality: Municipality.fromJson(row['municipality'] as String),
      sownDate: DateTime.parse(row['sown_date'] as String),
      syncStatus: SyncStatus.fromString(row['sync_status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
