import 'package:sqflite/sqflite.dart';

import '../../domain/models/crop.dart';
import '../../domain/models/crop_type.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/sync_status.dart';
import 'crop_sync_conflict.dart';
import 'local_db.dart';

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

  Future<List<Crop>> newLocalPendingByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 1 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.PENDING.name],
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Crop>> editedPendingByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 0 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.PENDING.name],
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Crop>> newLocalErrorByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 1 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.ERROR.name],
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Crop>> editedErrorByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE profile_id = ? AND sync_status = ? AND is_new_local = 0 AND pending_delete = 0 ORDER BY created_at ASC',
      [profileId, SyncStatus.ERROR.name],
    );
    return rows.map(_fromRow).toList();
  }

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

  Future<List<Crop>> pendingDeletesByProfile(String profileId) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'profile_id = ? AND pending_delete = 1 AND sync_status != ?',
      whereArgs: [profileId, SyncStatus.SYNCED.name],
    );
    return rows.map(_fromRow).toList();
  }

  /// Marca un tombstone local para ocultar el cultivo hasta confirmar el borrado remoto.
  Future<void> markDeletedPending(String id) async {
    final db = LocalDb.instance.db;
    await db.transaction((txn) async {
      await txn.delete('crop_events', where: 'crop_id = ?', whereArgs: [id]);
      await txn.update(
        _table,
        {
          'pending_delete': 1,
          'sync_status': SyncStatus.PENDING.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteLocal(String id) async {
    final db = LocalDb.instance.db;
    await db.transaction((txn) async {
      await txn.delete('crop_events', where: 'crop_id = ?', whereArgs: [id]);
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
    });
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
  ///
  /// Retorna lista de conflictos detectados cuando el servidor sobrescribe
  /// datos locales que tenían cambios sin sincronizar.
  Future<List<CropSyncConflict>> upsertFromServer(
    List<Crop> crops, {
    required String profileId,
  }) async {
    final db = LocalDb.instance.db;

    final conflicts = <CropSyncConflict>[];
    final pendingDeleteRows = await db.query(
      _table,
      columns: ['id'],
      where: 'profile_id = ? AND pending_delete = 1',
      whereArgs: [profileId],
    );
    final pendingDeleteIds = pendingDeleteRows
        .map((row) => row['id'] as String)
        .toSet();
    final effectiveRemote = crops
        .where((crop) => !pendingDeleteIds.contains(crop.id))
        .toList();
    final serverIds = crops.map((c) => c.id).toSet();

    for (final serverCrop in effectiveRemote) {
      final existingRows = await db.query(
        _table,
        where: 'id = ?',
        whereArgs: [serverCrop.id],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final localCrop = _fromRow(existingRows.first);
        final localUpdated = localCrop.updatedAt ?? localCrop.createdAt;
        final serverUpdated = serverCrop.updatedAt ?? serverCrop.createdAt;

        if (localUpdated.isAfter(serverUpdated)) {
          if (localCrop.areaHectares != serverCrop.areaHectares) {
            conflicts.add(
              CropSyncConflict(
                cropId: serverCrop.id,
                cropType: localCrop.cropType,
                fieldName: 'areaHectares',
                localValue: '${localCrop.areaHectares} ha',
                serverValue: '${serverCrop.areaHectares} ha',
              ),
            );
          }
          final localMun = localCrop.municipality.name;
          final serverMun = serverCrop.municipality.name;
          if (localMun != serverMun) {
            conflicts.add(
              CropSyncConflict(
                cropId: serverCrop.id,
                cropType: localCrop.cropType,
                fieldName: 'municipality',
                localValue: localCrop.municipality.label,
                serverValue: serverCrop.municipality.label,
              ),
            );
          }
          final localSown = _dateStr(localCrop.sownDate);
          final serverSown = _dateStr(serverCrop.sownDate);
          if (localSown != serverSown) {
            conflicts.add(
              CropSyncConflict(
                cropId: serverCrop.id,
                cropType: localCrop.cropType,
                fieldName: 'sownDate',
                localValue: localSown,
                serverValue: serverSown,
              ),
            );
          }
        }
      }
    }

    final batch = db.batch();
    for (final crop in effectiveRemote) {
      batch.insert(
        _table,
        _toRow(crop, profileId, isNewLocal: false),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    final localCrops = await listByProfile(profileId);
    final orphaned = localCrops
        .where((c) => !serverIds.contains(c.id))
        .map((c) => c.id)
        .toList();
    if (orphaned.isNotEmpty) {
      final placeholders = orphaned.map((_) => '?').join(', ');
      await db.rawDelete(
        'DELETE FROM crop_events WHERE crop_id IN ($placeholders)',
        orphaned,
      );
      await db.rawUpdate(
        'UPDATE $_table SET pending_delete = 1, sync_status = ? WHERE id IN ($placeholders) AND is_new_local = 0 AND pending_delete = 0',
        [SyncStatus.SYNCED.name, ...orphaned],
      );
    }

    return conflicts;
  }

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
        'updated_at':
            crop.updatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
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
      'updated_at': crop.updatedAt?.toIso8601String() ?? now,
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
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
