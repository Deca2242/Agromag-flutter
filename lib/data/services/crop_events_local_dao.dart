import 'package:sqflite/sqflite.dart';

import '../../domain/models/crop_event.dart';
import 'local_db.dart';

/// CRUD de la tabla `crop_events` en SQLite.
class CropEventsLocalDao {
  const CropEventsLocalDao();

  static const _table = 'crop_events';

  Future<void> upsert(CropEvent event) async {
    await LocalDb.instance.db.insert(
      _table,
      _toRow(event),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CropEvent>> listUnsynced() async {
    final rows = await LocalDb.instance.db.query(
      _table,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'event_date ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countUnsynced() async {
    final rows = await LocalDb.instance.db.rawQuery(
      'SELECT COUNT(*) as c FROM $_table WHERE synced = 0',
    );
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markEventsSynced(Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final db = LocalDb.instance.db;
    final placeholders = List.filled(idList.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_table SET synced = 1 WHERE id IN ($placeholders)',
      idList,
    );
  }

  Future<List<CropEvent>> listByCrop(String cropId) async {
    final rows = await LocalDb.instance.db.query(
      _table,
      where: 'crop_id = ?',
      whereArgs: [cropId],
      orderBy: 'event_date DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> upsertAll(List<CropEvent> events) async {
    if (events.isEmpty) return;
    final db = LocalDb.instance.db;
    final batch = db.batch();
    for (final e in events) {
      batch.insert(_table, _toRow(e),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteAllForCrop(String cropId) async {
    await LocalDb.instance.db
        .delete(_table, where: 'crop_id = ?', whereArgs: [cropId]);
  }

  static Map<String, dynamic> _toRow(CropEvent event) {
    return {
      'id': event.id,
      'crop_id': event.cropId,
      'event_type': event.eventType.name,
      'notes': event.notes,
      'event_date': event.occurredAt.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'synced': event.synced ? 1 : 0,
    };
  }

  static CropEvent _fromRow(Map<String, dynamic> row) {
    return CropEvent(
      id: row['id'] as String,
      cropId: row['crop_id'] as String,
      eventType: EventType.fromJson(row['event_type'] as String),
      occurredAt: DateTime.parse(row['event_date'] as String),
      notes: row['notes'] as String?,
      synced: (row['synced'] as int? ?? 1) == 1,
    );
  }
}
