import '../../core/errors/error_handling.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/recommendation.dart';
import '../../domain/models/recommendation_page.dart';
import '../services/pending_decisions_local_dao.dart';
import '../services/recommendations_api.dart';

class RecommendationsRepository {
  const RecommendationsRepository({
    required RecommendationsApi api,
    required PendingDecisionsLocalDao decisionsDao,
  })  : _api = api,
        _decisionsDao = decisionsDao;

  final RecommendationsApi _api;
  final PendingDecisionsLocalDao _decisionsDao;

  Future<void> submitDecision({
    required String recommendationId,
    required bool followed,
  }) async {
    try {
      await _api.submitDecision(
        recommendationId: recommendationId,
        followed: followed,
      );
    } on NetworkException {
      await _decisionsDao.insert(recommendationId, followed);
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

  Future<List<Recommendation>> listByCrop(String cropId) =>
      _api.listByCrop(cropId);

  Future<RecommendationPage> listByCropPaged(
    String cropId, {
    String followedFilter = 'any',
    int page = 0,
    int size = 10,
  }) =>
      _api.listByCropPaged(
        cropId,
        followedFilter: followedFilter,
        page: page,
        size: size,
      );

  Future<Recommendation> generateIrrigation(String cropId) =>
      _api.generateIrrigation(cropId);

  Future<Recommendation> generateFertilizer(String cropId) =>
      _api.generateFertilizer(cropId);

  Future<Recommendation> generatePhytosanitary(String cropId) =>
      _api.generatePhytosanitary(cropId);
}
