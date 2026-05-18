import 'dart:math' as math;

import '../../core/errors/error_handling.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/recommendation.dart';
import '../../domain/models/recommendation_page.dart';
import '../services/offline_rule_engine.dart';
import '../services/pending_decisions_local_dao.dart';
import '../services/recommendation_params_local_dao.dart';
import '../services/recommendations_api.dart';
import '../services/recommendations_local_dao.dart';
import '../services/weather_local_dao.dart';

// Repositorio de recomendaciones con estrategia online/offline.
// Si hay conexión: usa la API del backend (reglas + IA).
// Si no hay conexión: usa el motor de reglas local con clima cacheado.
class RecommendationsRepository {
  RecommendationsRepository({
    required RecommendationsApi api,
    required PendingDecisionsLocalDao decisionsDao,
    required RecommendationsLocalDao localDao,
    required WeatherLocalDao weatherDao,
    required OfflineRuleEngine ruleEngine,
    required RecommendationParamsLocalDao paramsDao,
  }) : _api = api,
       _decisionsDao = decisionsDao,
       _localDao = localDao,
       _weatherDao = weatherDao,
       _ruleEngine = ruleEngine,
       _paramsDao = paramsDao;

  final RecommendationsApi _api;
  final PendingDecisionsLocalDao _decisionsDao;
  final RecommendationsLocalDao _localDao;
  final WeatherLocalDao _weatherDao;
  final OfflineRuleEngine _ruleEngine;
  final RecommendationParamsLocalDao _paramsDao;

  // Genera un ID único simple para recomendaciones locales sin depender de uuid.
  static String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = math.Random().nextInt(0xFFFFFF);
    return 'local-$ts-${rnd.toRadixString(16)}';
  }

  Future<void> submitDecision({
    required String recommendationId,
    required bool followed,
  }) async {
    try {
      await _api.submitDecision(
        recommendationId: recommendationId,
        followed: followed,
      );
      await _localDao.updateFollowed(recommendationId, followed);
    } on NetworkException {
      await _decisionsDao.insert(recommendationId, followed);
      await _localDao.updateFollowed(recommendationId, followed);
    }
  }

  Future<bool> syncPendingDecisions() async {
    final pending = await _decisionsDao.listAll();
    if (pending.isEmpty) return true;

    try {
      for (final decision in pending) {
        await _api.submitDecision(
          recommendationId: decision.recommendationId,
          followed: decision.followed,
        );
      }
      final ids = pending.map((d) => d.id).toList();
      await _decisionsDao.deleteByIds(ids);
      return true;
    } catch (error, stackTrace) {
      AppErrorHandling.report(
        'recommendation_decisions_sync_failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<int> countPendingDecisions() => _decisionsDao.countPending();

  Future<void> resetDecision(String recommendationId) =>
      _api.resetDecision(recommendationId);

  // Lista recomendaciones pendientes de un cultivo.
  // Si falla la red, retorna las almacenadas localmente.
  Future<List<Recommendation>> listByCrop(String cropId) async {
    try {
      final result = await _api.listByCrop(cropId);
      await _localDao.upsertAll(result);
      return result;
    } on NetworkException {
      return _localDao.listByCrop(cropId);
    } catch (_) {
      return _localDao.listByCrop(cropId);
    }
  }

  // Lista recomendaciones pendientes de un cultivo, cacheando el resultado.
  // Antes de insertar desde el backend, elimina las versiones RULE_LOCAL del
  // mismo tipo para que la versión AI/RULE del servidor tenga prioridad.
  // En caso de error de red, cae al cache local.
  Future<List<Recommendation>> listPendingByCrop(
    String cropId, {
    int size = 5,
  }) async {
    try {
      final page = await _api.listByCropPaged(
        cropId,
        followedFilter: 'pending',
        page: 0,
        size: size,
      );
      final items = page.items;
      if (items.isNotEmpty) {
        final types = items
            .where((r) => r.type != null)
            .map((r) => r.type!.name.toUpperCase())
            .toSet()
            .toList();
        await _localDao.deleteOfflineByCropAndTypeIn(cropId, types);
        await _localDao.upsertAll(items);
      }
      return items;
    } on NetworkException {
      return _localDao.listByCrop(cropId);
    } catch (_) {
      return _localDao.listByCrop(cropId);
    }
  }

  // Lista paginada con fallback offline.
  // Online: llama a la API y cachea pending; no cachea decided (historial grande).
  // Offline / NetworkException: usa SQLite local.
  Future<RecommendationPage> listByCropPagedWithFallback(
    String cropId, {
    String followedFilter = 'any',
    int page = 0,
    int size = 10,
  }) async {
    try {
      return await _api.listByCropPaged(
        cropId,
        followedFilter: followedFilter,
        page: page,
        size: size,
      );
    } on NetworkException {
      return _buildLocalPage(cropId, followedFilter: followedFilter, page: page, size: size);
    } catch (_) {
      return _buildLocalPage(cropId, followedFilter: followedFilter, page: page, size: size);
    }
  }

  Future<RecommendationPage> _buildLocalPage(
    String cropId, {
    required String followedFilter,
    required int page,
    required int size,
  }) async {
    final List<Recommendation> items;
    if (followedFilter == 'decided') {
      items = await _localDao.listDecidedByCropPaged(
        cropId,
        page: page,
        size: size,
      );
    } else {
      items = await _localDao.listByCrop(cropId);
    }
    return RecommendationPage(
      items: items,
      totalElements: items.length,
      totalPages: items.isEmpty ? 0 : 1,
      pageNumber: 0,
      pageSize: size,
    );
  }

  // Genera las 3 recomendaciones offline para un cultivo usando el motor de reglas local.
  // Si hay clima cacheado, genera las 3 reglas completas.
  // Si no hay clima, genera solo la regla de fertilización (no depende de clima)
  // y mensajes informativos para riego y fitosanitario.
  // Siempre persiste los resultados para que sobrevivan reinicios.
  Future<List<Recommendation>> generateOffline(Crop crop) async {
    final weather = await _weatherDao.find(crop.municipality);

    final results = await _ruleEngine.evaluateAll(crop, weather);

    final recommendations = results.map((result) {
      return Recommendation.fromOfflineResult(result, crop, _generateId());
    }).toList();

    await _localDao.upsertAll(recommendations);
    return recommendations;
  }

  // Lista hasta [limit] recomendaciones pendientes de todos los cultivos desde caché local.
  // Se usa como fallback del dashboard cuando no hay conexión.
  Future<List<Recommendation>> listPendingFromCache({int limit = 3}) =>
      _localDao.listPendingAll(limit: limit);

  // Sincroniza los parámetros del motor de reglas con el backend.
  // Retorna true si el sync fue exitoso.
  Future<bool> syncRuleParameters() async {
    try {
      final params = await _api.fetchParameters();
      await _paramsDao.saveAll(params);
      await _ruleEngine.warmUp();
      return true;
    } catch (error, stackTrace) {
      AppErrorHandling.report(
        'recommendation_params_sync_failed',
        error,
        stackTrace,
      );
      return false;
    }
  }
}
