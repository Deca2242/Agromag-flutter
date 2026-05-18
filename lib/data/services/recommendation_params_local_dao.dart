import 'package:sqflite/sqflite.dart';

import '../../domain/models/crop_parameters.dart';
import 'local_db.dart';

// DAO para la tabla `recommendation_params_cache`.
// Almacena los umbrales del motor de reglas del backend como pares clave-valor.
// Permite que el OfflineRuleEngine use parámetros actualizados sin cambiar la app.
class RecommendationParamsLocalDao {
  const RecommendationParamsLocalDao();

  static const _table = 'recommendation_params_cache';

  // Persiste todos los parámetros del mapa en una sola transacción.
  Future<void> saveAll(Map<String, String> params) async {
    if (params.isEmpty) return;
    final db = LocalDb.instance.db;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final entry in params.entries) {
      batch.insert(
        _table,
        {'key': entry.key, 'value': entry.value, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Carga todos los parámetros guardados como mapa clave-valor.
  Future<Map<String, String>> loadAll() async {
    final db = LocalDb.instance.db;
    final rows = await db.query(_table);
    return {
      for (final row in rows)
        row['key'] as String: row['value'] as String,
    };
  }

  // Carga los parámetros o devuelve los valores de respaldo si la tabla está vacía.
  Future<OfflineRuleDefaults> loadOrFallback() async {
    final map = await loadAll();
    if (map.isEmpty) return OfflineRuleDefaults.fallback;
    return OfflineRuleDefaults.fromCacheMap(map);
  }

  Future<void> clear() async {
    final db = LocalDb.instance.db;
    await db.delete(_table);
  }
}
