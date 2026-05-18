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

/// Repositorio de recomendaciones con estrategia online/offline.
///
/// Online: delega a la API del backend (reglas + IA).
/// Offline: usa el motor de reglas local con clima cacheado.
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

  /// UUID ligero para recomendaciones generadas localmente.
  /// No usa el paquete uuid para evitar la dependencia en contextos offline puros.
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

  /// Antes de cachear resultados del backend, elimina las versiones RULE_LOCAL
  /// del mismo tipo para que la versión del servidor tenga prioridad.
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

  Future<List<Recommendation>> generateOffline(Crop crop) async {
    final weather = await _weatherDao.find(crop.municipality);

    final results = await _ruleEngine.evaluateAll(crop, weather);

    final recommendations = results.map((result) {
      return Recommendation.fromOfflineResult(result, crop, _generateId());
    }).toList();

    await _localDao.upsertAll(recommendations);
    return recommendations;
  }

  Future<List<Recommendation>> listPendingFromCache({int limit = 3}) =>
      _localDao.listPendingAll(limit: limit);

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
