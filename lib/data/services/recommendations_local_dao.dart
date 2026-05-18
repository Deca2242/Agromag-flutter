import 'package:sqflite/sqflite.dart';

import '../../domain/models/recommendation.dart';
import 'local_db.dart';

// DAO para la tabla `recommendations_cache` en SQLite.
// Persiste recomendaciones generadas offline y las del backend para acceso sin red.
class RecommendationsLocalDao {
  const RecommendationsLocalDao();

  static const _table = 'recommendations_cache';

  // Inserta o reemplaza la recomendación de un tipo dado para un cultivo.
  // Solo se conserva la más reciente por (crop_id, type).
  Future<void> upsert(Recommendation rec) async {
    final db = LocalDb.instance.db;
    await db.insert(
      _table,
      _toRow(rec),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Inserta o reemplaza múltiples recomendaciones en una sola transacción.
  Future<void> upsertAll(List<Recommendation> recs) async {
    if (recs.isEmpty) return;
    final db = LocalDb.instance.db;
    final batch = db.batch();
    for (final rec in recs) {
      batch.insert(
        _table,
        _toRow(rec),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Lista todas las recomendaciones de un cultivo, ordenadas de más reciente a más antigua.
  Future<List<Recommendation>> listByCrop(String cropId) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'crop_id = ?',
      whereArgs: [cropId],
      orderBy: 'generated_at DESC',
    );
    return rows.map(Recommendation.fromLocalRow).toList();
  }

  // Lista recomendaciones pendientes de decisión de todos los cultivos.
  // Filtra filas con type NULL o 'UNKNOWN' (tipos no reconocidos).
  // Máximo [limit] resultados, ordenados por fecha descendente.
  Future<List<Recommendation>> listPendingAll({int limit = 10}) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: "followed IS NULL AND type IS NOT NULL AND type != 'UNKNOWN'",
      orderBy: 'generated_at DESC',
      limit: limit,
    );
    return rows.map(Recommendation.fromLocalRow).toList();
  }

  // Lista recomendaciones con decisión tomada para un cultivo, paginadas.
  // Se usa como fallback offline del historial de decisiones.
  Future<List<Recommendation>> listDecidedByCropPaged(
    String cropId, {
    int page = 0,
    int size = 10,
  }) async {
    final db = LocalDb.instance.db;
    final rows = await db.query(
      _table,
      where: 'crop_id = ? AND followed IS NOT NULL',
      whereArgs: [cropId],
      orderBy: 'generated_at DESC',
      limit: size,
      offset: page * size,
    );
    return rows.map(Recommendation.fromLocalRow).toList();
  }

  // Elimina recomendaciones offline (source = RULE_LOCAL) de un cultivo
  // para un conjunto de tipos. Se usa al recibir versiones del backend
  // para evitar duplicados con distinto id.
  Future<void> deleteOfflineByCropAndTypeIn(
    String cropId,
    List<String> types,
  ) async {
    if (types.isEmpty) return;
    final db = LocalDb.instance.db;
    final placeholders = List.filled(types.length, '?').join(',');
    await db.rawDelete(
      'DELETE FROM $_table WHERE crop_id = ? AND type IN ($placeholders) AND source = ?',
      [cropId, ...types, 'RULE_LOCAL'],
    );
  }

  // Actualiza la decisión del productor sobre una recomendación local.
  Future<void> updateFollowed(String id, bool followed) async {
    final db = LocalDb.instance.db;
    await db.update(
      _table,
      {'followed': followed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Elimina todas las recomendaciones de un cultivo (al borrar el cultivo).
  Future<void> deleteByCrop(String cropId) async {
    final db = LocalDb.instance.db;
    await db.delete(_table, where: 'crop_id = ?', whereArgs: [cropId]);
  }

  // Elimina las recomendaciones offline de un cultivo para un tipo específico.
  // Se usa al recibir nuevas recomendaciones del backend.
  Future<void> deleteOfflineByCropAndType(
    String cropId,
    String type,
  ) async {
    final db = LocalDb.instance.db;
    await db.delete(
      _table,
      where: 'crop_id = ? AND type = ? AND source = ?',
      whereArgs: [cropId, type, 'RULE_LOCAL'],
    );
  }

  // Limpia toda la tabla (al cerrar sesión).
  Future<void> clear() async {
    final db = LocalDb.instance.db;
    await db.delete(_table);
  }

  static Map<String, dynamic> _toRow(Recommendation rec) {
    return {
      'id': rec.id,
      'crop_id': rec.cropId ?? '',
      // 'UNKNOWN' para tipos no reconocidos: evita violar NOT NULL en esquemas
      // anteriores (< v9) y permite filtrarlos en listPendingAll.
      'type': rec.type?.name.toUpperCase() ?? 'UNKNOWN',
      'level': _levelToBackend(rec.level),
      'message': rec.body,
      'source': rec.source ?? 'RULE_LOCAL',
      'generated_at': rec.generatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'crop_type': rec.cropTypeCode,
      'followed': rec.followed == null ? null : (rec.followed! ? 1 : 0),
    };
  }

  static String _levelToBackend(RecommendationLevel level) {
    return switch (level) {
      RecommendationLevel.alert => 'HIGH',
      RecommendationLevel.moderate => 'MEDIUM',
      RecommendationLevel.optimal => 'LOW',
    };
  }
}
