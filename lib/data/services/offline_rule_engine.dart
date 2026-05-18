import '../../domain/models/crop.dart';
import '../../domain/models/crop_parameters.dart';
import '../../domain/models/crop_type.dart';
import '../../domain/models/offline_recommendation_result.dart';
import '../../domain/models/recommendation.dart';
import '../../domain/models/weather.dart';
import 'recommendation_params_local_dao.dart';

// Motor de reglas agronómicas offline.
// Replica la lógica de RecommendationService.java del backend Spring Boot.
// Opera completamente sin conexión usando cultivos locales, clima cacheado
// y parámetros agronómicos embebidos (o actualizados desde el backend).
class OfflineRuleEngine {
  OfflineRuleEngine({required RecommendationParamsLocalDao paramsDao})
      : _paramsDao = paramsDao;

  final RecommendationParamsLocalDao _paramsDao;

  // Cache interno de umbrales; se carga la primera vez que se necesita.
  OfflineRuleDefaults? _defaults;


  // Carga los umbrales desde SQLite (o usa los valores de respaldo hardcoded).
  // Resultado cacheado en memoria para llamadas subsiguientes.
  Future<OfflineRuleDefaults> _getDefaults() async {
    _defaults ??= await _paramsDao.loadOrFallback();
    return _defaults!;
  }

  // Fuerza recarga de los umbrales desde SQLite (llamar después de un sync).
  Future<void> warmUp() async {
    _defaults = await _paramsDao.loadOrFallback();
  }

  // Evalúa las tres reglas (riego, fertilización, fitosanitario) para un cultivo.
  // Devuelve lista de 3 resultados en el mismo orden.
  Future<List<OfflineRecommendationResult>> evaluateAll(
    Crop crop,
    CurrentWeather? weather,
  ) async {
    final params = kCropParameters[crop.cropType];
    final now = DateTime.now();

    if (params == null) {
      return _fallbackResults(crop, now);
    }

    final defaults = await _getDefaults();
    return [
      _computeIrrigation(crop, weather, params, defaults, now),
      _computeFertilizer(crop, params, defaults, now),
      _computePhytosanitary(crop, weather, defaults, now),
    ];
  }

  // Regla de riego:
  // HIGH si temp excede máxima óptima o humedad está por debajo del mínimo.
  // MEDIUM si temp está cerca de exceder el máximo (dentro del delta configurado).
  // LOW si todo está en rango óptimo.
  // Si no hay datos de clima muestra mensaje informativo con nivel LOW.
  OfflineRecommendationResult _computeIrrigation(
    Crop crop,
    CurrentWeather? weather,
    CropParameters params,
    OfflineRuleDefaults defaults,
    DateTime now,
  ) {
    if (weather == null) {
      return OfflineRecommendationResult(
        type: RecommendationType.irrigation,
        level: RecommendationLevel.optimal,
        message:
            'No hay datos de clima en caché para ${crop.municipality.label}. '
            'Conéctese al menos una vez para obtener datos climáticos '
            'y calcular recomendaciones de riego precisas.',
        generatedAt: now,
      );
    }

    final temp = weather.temperature;
    final hum = weather.humidity;
    final maxTemp = params.optimalTempMax;
    final minHum = params.humidityMin;

    final tempExceeded = temp > maxTemp;
    final humLow = hum < minHum;
    final tempNearMax = temp > (maxTemp - defaults.irrigationNearMaxDelta);

    final RecommendationLevel level;
    final String message;

    if (tempExceeded || humLow) {
      level = RecommendationLevel.alert;
      message =
          '¡Alerta! Temperatura: ${temp.toStringAsFixed(1)}°C '
          '(máx óptima: ${maxTemp.toStringAsFixed(1)}°C), '
          'Humedad: ${hum.toStringAsFixed(0)}% '
          '(mín óptima: ${minHum.toStringAsFixed(0)}%). '
          'Se recomienda riego inmediato. '
          'Referencia de riego para ${crop.cropType.label}: ${params.irrigationNeeds}.';
    } else if (tempNearMax) {
      level = RecommendationLevel.moderate;
      message =
          'La temperatura actual (${temp.toStringAsFixed(1)}°C) se acerca a la máxima '
          'óptima (${maxTemp.toStringAsFixed(1)}°C). '
          'Considere programar riego en las próximas horas. '
          'Referencia: ${params.irrigationNeeds}.';
    } else {
      level = RecommendationLevel.optimal;
      message =
          'Condiciones dentro del rango óptimo '
          '(Temp: ${temp.toStringAsFixed(1)}°C, Hum: ${hum.toStringAsFixed(0)}%). '
          'No se requiere riego adicional por ahora.';
    }

    return OfflineRecommendationResult(
      type: RecommendationType.irrigation,
      level: level,
      message: message,
      generatedAt: now,
    );
  }

  // Regla de fertilización:
  // Determina la etapa del cultivo según semanas transcurridas desde la siembra
  // y recomienda el nutriente correspondiente.
  // No requiere datos de clima.
  OfflineRecommendationResult _computeFertilizer(
    Crop crop,
    CropParameters params,
    OfflineRuleDefaults defaults,
    DateTime now,
  ) {
    final weeks = now.difference(crop.sownDate).inDays ~/ 7;
    final initialWeeks = defaults.fertilizerInitialStageWeeks;
    final vegetativeWeeks = defaults.fertilizerVegetativeStageWeeks;

    final RecommendationLevel level;
    final String message;

    if (weeks < initialWeeks) {
      level = RecommendationLevel.alert;
      message =
          'Etapa inicial ($weeks semanas). Se sugiere aplicar nitrógeno (N) '
          'para estimular el crecimiento radicular. '
          'Referencia base: ${params.recommendedFertilizer}.';
    } else if (weeks <= vegetativeWeeks) {
      level = RecommendationLevel.moderate;
      message =
          'Etapa de desarrollo ($weeks semanas). Se sugiere fertilización NPK balanceada. '
          'Referencia base: ${params.recommendedFertilizer}.';
    } else {
      level = RecommendationLevel.moderate;
      message =
          'Etapa de producción ($weeks semanas). Se sugiere reforzar potasio (K) '
          'para calidad del fruto. '
          'Referencia base: ${params.recommendedFertilizer}.';
    }

    return OfflineRecommendationResult(
      type: RecommendationType.fertilizer,
      level: level,
      message: message,
      generatedAt: now,
    );
  }

  // Regla fitosanitaria:
  // HIGH si temperatura Y humedad superan ambos umbrales (condición de doble riesgo).
  // MEDIUM si solo uno de los dos factores supera el umbral.
  // LOW si las condiciones están dentro del rango normal.
  // Si no hay datos de clima muestra mensaje informativo con nivel LOW.
  OfflineRecommendationResult _computePhytosanitary(
    Crop crop,
    CurrentWeather? weather,
    OfflineRuleDefaults defaults,
    DateTime now,
  ) {
    if (weather == null) {
      return OfflineRecommendationResult(
        type: RecommendationType.phytosanitary,
        level: RecommendationLevel.optimal,
        message:
            'No hay datos de clima en caché para ${crop.municipality.label}. '
            'Conéctese al menos una vez para evaluar riesgo fitosanitario '
            'basado en temperatura y humedad actuales.',
        generatedAt: now,
      );
    }

    final temp = weather.temperature;
    final hum = weather.humidity;
    final highTemp = temp > defaults.phytoTempThreshold;
    final highHum = hum > defaults.phytoHumidityThreshold;
    final pests = crop.cropType.commonPests;

    final RecommendationLevel level;
    final String message;

    if (highTemp && highHum) {
      level = RecommendationLevel.alert;
      message =
          '¡Alerta fitosanitaria! Temperatura: ${temp.toStringAsFixed(1)}°C '
          'y humedad: ${hum.toStringAsFixed(0)}% superan los umbrales '
          'de riesgo (>${defaults.phytoTempThreshold.toStringAsFixed(0)}°C '
          'y >${defaults.phytoHumidityThreshold.toStringAsFixed(0)}%). '
          'Revise su cultivo de ${crop.cropType.label} hoy. '
          'Plagas probables: $pests.';
    } else if (highTemp || highHum) {
      final condition = highTemp
          ? 'temperatura alta (${temp.toStringAsFixed(1)}°C)'
          : 'humedad alta (${hum.toStringAsFixed(0)}%)';
      level = RecommendationLevel.moderate;
      message =
          'Condición de riesgo moderado: $condition. '
          'Monitoree su cultivo de ${crop.cropType.label}. '
          'Posibles plagas: $pests.';
    } else {
      level = RecommendationLevel.optimal;
      message =
          'Condiciones climáticas dentro del rango normal '
          '(Temp: ${temp.toStringAsFixed(1)}°C, Hum: ${hum.toStringAsFixed(0)}%). '
          'No se detectan condiciones de riesgo fitosanitario elevado.';
    }

    return OfflineRecommendationResult(
      type: RecommendationType.phytosanitary,
      level: level,
      message: message,
      generatedAt: now,
      suspectedPests: highTemp || highHum ? pests : null,
    );
  }

  // Resultados de fallback cuando no hay parámetros disponibles para el tipo de cultivo.
  List<OfflineRecommendationResult> _fallbackResults(Crop crop, DateTime now) {
    const fallbackMessage =
        'No se pudieron calcular parámetros locales para este cultivo. '
        'Conéctese para obtener recomendaciones precisas.';
    return [
      OfflineRecommendationResult(
        type: RecommendationType.irrigation,
        level: RecommendationLevel.optimal,
        message: fallbackMessage,
        generatedAt: now,
      ),
      OfflineRecommendationResult(
        type: RecommendationType.fertilizer,
        level: RecommendationLevel.optimal,
        message: fallbackMessage,
        generatedAt: now,
      ),
      OfflineRecommendationResult(
        type: RecommendationType.phytosanitary,
        level: RecommendationLevel.optimal,
        message: fallbackMessage,
        generatedAt: now,
      ),
    ];
  }
}
