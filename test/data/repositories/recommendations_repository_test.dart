import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:app/core/network/api_exceptions.dart';
import 'package:app/data/repositories/recommendations_repository.dart';
import 'package:app/data/services/offline_rule_engine.dart';
import 'package:app/data/services/pending_decisions_local_dao.dart';
import 'package:app/data/services/recommendation_params_local_dao.dart';
import 'package:app/data/services/recommendations_api.dart';
import 'package:app/data/services/recommendations_local_dao.dart';
import 'package:app/data/services/weather_local_dao.dart';
import 'package:app/domain/models/crop.dart';
import 'package:app/domain/models/crop_type.dart';
import 'package:app/domain/models/municipality.dart';
import 'package:app/domain/models/offline_recommendation_result.dart';
import 'package:app/domain/models/recommendation.dart';
import 'package:app/domain/models/recommendation_page.dart';
import 'package:app/domain/models/sync_status.dart';
import 'package:app/domain/models/weather.dart';

class MockRecommendationsApi extends Mock implements RecommendationsApi {}

class MockRecommendationsLocalDao extends Mock
    implements RecommendationsLocalDao {}

class MockPendingDecisionsLocalDao extends Mock
    implements PendingDecisionsLocalDao {}

class MockWeatherLocalDao extends Mock implements WeatherLocalDao {}

class MockOfflineRuleEngine extends Mock implements OfflineRuleEngine {}

class MockRecommendationParamsLocalDao extends Mock
    implements RecommendationParamsLocalDao {}

void main() {
  late MockRecommendationsApi mockApi;
  late MockRecommendationsLocalDao mockLocalDao;
  late MockPendingDecisionsLocalDao mockDecisionsDao;
  late MockWeatherLocalDao mockWeatherDao;
  late MockOfflineRuleEngine mockEngine;
  late MockRecommendationParamsLocalDao mockParamsDao;
  late RecommendationsRepository repo;

  final now = DateTime(2026, 5, 18);

  Recommendation makeRec({
    String id = 'rec-1',
    String cropId = 'crop-1',
    RecommendationType type = RecommendationType.irrigation,
    String source = 'RULE',
  }) {
    return Recommendation(
      id: id,
      title: 'Riego',
      body: 'Mensaje de prueba',
      level: RecommendationLevel.optimal,
      iconCodePoint: 0,
      accentColor: const Color(0xFF0000FF),
      cropId: cropId,
      type: type,
      source: source,
      generatedAt: now,
    );
  }

  Crop makeCrop() {
    return Crop(
      id: 'crop-1',
      cropType: CropType.BANANO,
      areaHectares: 1.0,
      municipality: Municipality.ZONA_BANANERA,
      sownDate: now.subtract(const Duration(days: 30)),
      syncStatus: SyncStatus.SYNCED,
      createdAt: now,
    );
  }

  setUp(() {
    mockApi = MockRecommendationsApi();
    mockLocalDao = MockRecommendationsLocalDao();
    mockDecisionsDao = MockPendingDecisionsLocalDao();
    mockWeatherDao = MockWeatherLocalDao();
    mockEngine = MockOfflineRuleEngine();
    mockParamsDao = MockRecommendationParamsLocalDao();

    repo = RecommendationsRepository(
      api: mockApi,
      decisionsDao: mockDecisionsDao,
      localDao: mockLocalDao,
      weatherDao: mockWeatherDao,
      ruleEngine: mockEngine,
      paramsDao: mockParamsDao,
    );
  });

  group('listByCrop', () {
    test('llama a la API, cachea en SQLite y retorna los items', () async {
      final recs = [makeRec(), makeRec(id: 'rec-2')];
      when(() => mockApi.listByCrop('crop-1')).thenAnswer((_) async => recs);
      when(() => mockLocalDao.upsertAll(any())).thenAnswer((_) async {});

      final result = await repo.listByCrop('crop-1');

      expect(result, recs);
      verify(() => mockLocalDao.upsertAll(recs)).called(1);
    });

    test('cae al DAO local cuando hay NetworkException', () async {
      final localRecs = [makeRec(source: 'RULE_LOCAL')];
      when(() => mockApi.listByCrop('crop-1'))
          .thenThrow(const NetworkException());
      when(
        () => mockLocalDao.listByCrop('crop-1'),
      ).thenAnswer((_) async => localRecs);

      final result = await repo.listByCrop('crop-1');

      expect(result, localRecs);
      verifyNever(() => mockLocalDao.upsertAll(any()));
    });
  });

  group('listPendingByCrop', () {
    test('elimina versiones RULE_LOCAL y cachea items del backend', () async {
      final recs = [makeRec(source: 'AI')];
      final page = RecommendationPage(
        items: recs,
        totalElements: 1,
        totalPages: 1,
        pageNumber: 0,
        pageSize: 5,
      );
      when(
        () => mockApi.listByCropPaged(
          'crop-1',
          followedFilter: 'pending',
          page: 0,
          size: 5,
        ),
      ).thenAnswer((_) async => page);
      when(
        () => mockLocalDao.deleteOfflineByCropAndTypeIn('crop-1', any()),
      ).thenAnswer((_) async {});
      when(() => mockLocalDao.upsertAll(any())).thenAnswer((_) async {});

      final result = await repo.listPendingByCrop('crop-1');

      expect(result, recs);
      verify(
        () => mockLocalDao.deleteOfflineByCropAndTypeIn('crop-1', any()),
      ).called(1);
      verify(() => mockLocalDao.upsertAll(recs)).called(1);
    });

    test('cae al DAO local cuando hay NetworkException', () async {
      final localRecs = [makeRec(source: 'RULE_LOCAL')];
      when(
        () => mockApi.listByCropPaged(
          'crop-1',
          followedFilter: 'pending',
          page: 0,
          size: 5,
        ),
      ).thenThrow(const NetworkException());
      when(
        () => mockLocalDao.listByCrop('crop-1'),
      ).thenAnswer((_) async => localRecs);

      final result = await repo.listPendingByCrop('crop-1');

      expect(result, localRecs);
    });
  });

  group('submitDecision', () {
    test('llama a la API y actualiza SQLite cuando hay conexión', () async {
      when(
        () => mockApi.submitDecision(
          recommendationId: 'rec-1',
          followed: true,
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalDao.updateFollowed('rec-1', true),
      ).thenAnswer((_) async {});

      await repo.submitDecision(
        recommendationId: 'rec-1',
        followed: true,
      );

      verify(
        () => mockApi.submitDecision(
          recommendationId: 'rec-1',
          followed: true,
        ),
      ).called(1);
      verify(() => mockLocalDao.updateFollowed('rec-1', true)).called(1);
    });

    test('encola en pending_decisions y actualiza SQLite cuando hay NetworkException', () async {
      when(
        () => mockApi.submitDecision(
          recommendationId: 'rec-1',
          followed: false,
        ),
      ).thenThrow(const NetworkException());
      when(
        () => mockDecisionsDao.insert('rec-1', false),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalDao.updateFollowed('rec-1', false),
      ).thenAnswer((_) async {});

      await repo.submitDecision(
        recommendationId: 'rec-1',
        followed: false,
      );

      verify(() => mockDecisionsDao.insert('rec-1', false)).called(1);
      verify(() => mockLocalDao.updateFollowed('rec-1', false)).called(1);
    });
  });

  group('syncPendingDecisions', () {
    test('retorna true y borra solo los ids procesados exitosamente', () async {
      final decisions = [
        PendingDecisionRecord(
          id: 1,
          recommendationId: 'rec-1',
          followed: true,
          createdAt: now,
        ),
        PendingDecisionRecord(
          id: 2,
          recommendationId: 'rec-2',
          followed: false,
          createdAt: now,
        ),
      ];
      when(() => mockDecisionsDao.listAll()).thenAnswer((_) async => decisions);
      when(
        () => mockApi.submitDecision(
          recommendationId: any(named: 'recommendationId'),
          followed: any(named: 'followed'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockDecisionsDao.deleteByIds(any())).thenAnswer((_) async {});

      final result = await repo.syncPendingDecisions();

      expect(result, isTrue);
      verify(() => mockDecisionsDao.deleteByIds([1, 2])).called(1);
    });

    test('retorna true y no llama a la API si no hay decisiones pendientes', () async {
      when(() => mockDecisionsDao.listAll()).thenAnswer((_) async => []);

      final result = await repo.syncPendingDecisions();

      expect(result, isTrue);
      verifyNever(
        () => mockApi.submitDecision(
          recommendationId: any(named: 'recommendationId'),
          followed: any(named: 'followed'),
        ),
      );
    });
  });

  group('generateOffline', () {
    test('genera recomendaciones completas cuando hay clima en caché', () async {
      final crop = makeCrop();
      final weather = CurrentWeather(
        temperature: 25.0,
        humidity: 70.0,
        fetchedAt: now,
      );
      final offlineResults = [
        OfflineRecommendationResult(
          type: RecommendationType.irrigation,
          level: RecommendationLevel.optimal,
          message: 'OK riego',
          generatedAt: now,
        ),
        OfflineRecommendationResult(
          type: RecommendationType.fertilizer,
          level: RecommendationLevel.moderate,
          message: 'NPK',
          generatedAt: now,
        ),
        OfflineRecommendationResult(
          type: RecommendationType.phytosanitary,
          level: RecommendationLevel.optimal,
          message: 'OK',
          generatedAt: now,
        ),
      ];

      when(
        () => mockWeatherDao.find(Municipality.ZONA_BANANERA),
      ).thenAnswer((_) async => weather);
      when(
        () => mockEngine.evaluateAll(crop, weather),
      ).thenAnswer((_) async => offlineResults);
      when(() => mockLocalDao.upsertAll(any())).thenAnswer((_) async {});

      final result = await repo.generateOffline(crop);

      expect(result, hasLength(3));
      verify(() => mockLocalDao.upsertAll(any())).called(1);
    });

    test('genera recomendaciones degradadas cuando no hay clima en caché', () async {
      final crop = makeCrop();
      final degradedResults = [
        OfflineRecommendationResult(
          type: RecommendationType.irrigation,
          level: RecommendationLevel.optimal,
          message: 'No hay datos de clima en caché',
          generatedAt: now,
        ),
        OfflineRecommendationResult(
          type: RecommendationType.fertilizer,
          level: RecommendationLevel.alert,
          message: 'Etapa inicial 4 semanas',
          generatedAt: now,
        ),
        OfflineRecommendationResult(
          type: RecommendationType.phytosanitary,
          level: RecommendationLevel.optimal,
          message: 'No hay datos de clima en caché',
          generatedAt: now,
        ),
      ];

      when(
        () => mockWeatherDao.find(Municipality.ZONA_BANANERA),
      ).thenAnswer((_) async => null);
      when(
        () => mockEngine.evaluateAll(crop, null),
      ).thenAnswer((_) async => degradedResults);
      when(() => mockLocalDao.upsertAll(any())).thenAnswer((_) async {});

      final result = await repo.generateOffline(crop);

      expect(result, hasLength(3));
      // Siempre persiste aunque sea degradado
      verify(() => mockLocalDao.upsertAll(any())).called(1);
    });
  });
}
