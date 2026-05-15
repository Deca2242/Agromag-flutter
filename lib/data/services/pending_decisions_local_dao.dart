import 'package:sqflite/sqflite.dart';

import 'local_db.dart';

class PendingDecisionRecord {
  const PendingDecisionRecord({
    required this.id,
    required this.recommendationId,
    required this.followed,
    required this.createdAt,
  });

  final int id;
  final String recommendationId;
  final bool followed;
  final DateTime createdAt;

  Map<String, dynamic> toRow() {
    return {
      'recommendation_id': recommendationId,
      'followed': followed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static PendingDecisionRecord fromRow(Map<String, dynamic> row) {
    return PendingDecisionRecord(
      id: row['id'] as int,
      recommendationId: row['recommendation_id'] as String,
      followed: (row['followed'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, dynamic> toSyncJson() {
    return {'recommendationId': recommendationId, 'followed': followed};
  }
}

class PendingDecisionsLocalDao {
  const PendingDecisionsLocalDao();

  static const _table = 'pending_decisions';

  Future<void> insert(String recommendationId, bool followed) async {
    final db = LocalDb.instance.db;
    await db.insert(_table, {
      'recommendation_id': recommendationId,
      'followed': followed ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PendingDecisionRecord>> listAll() async {
    final db = LocalDb.instance.db;
    final rows = await db.query(_table, orderBy: 'created_at ASC');
    return rows.map(PendingDecisionRecord.fromRow).toList();
  }

  Future<int> countPending() async {
    final db = LocalDb.instance.db;
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> deleteByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final db = LocalDb.instance.db;
    final idList = ids.toList();
    final placeholders = List.filled(idList.length, '?').join(',');
    await db.rawUpdate(
      'DELETE FROM $_table WHERE id IN ($placeholders)',
      idList,
    );
  }

  Future<void> clear() async {
    final db = LocalDb.instance.db;
    await db.delete(_table);
  }
}
