import 'crop_type.dart';

// Umbrales del motor de reglas agronómicas.
// Valores hardcoded que reflejan RecommendationProperties.java / application.properties.
// El SyncCoordinator los actualiza desde GET /api/recommendations/parameters
// y los almacena en `recommendation_params_cache`. El motor carga los valores
// cacheados en tiempo de ejecución; si no hay caché usa estos valores de respaldo.
class OfflineRuleDefaults {
  const OfflineRuleDefaults({
    this.phytoTempThreshold = 30.0,
    this.phytoHumidityThreshold = 80.0,
    this.irrigationNearMaxDelta = 3.0,
    this.fertilizerInitialStageWeeks = 4,
    this.fertilizerVegetativeStageWeeks = 12,
  });

  // Temperatura (°C) a partir de la cual se activa alerta fitosanitaria
  final double phytoTempThreshold;

  // Humedad relativa (%) a partir de la cual se activa alerta fitosanitaria
  final double phytoHumidityThreshold;

  // Delta (°C) respecto a la temp. máxima óptima para riego preventivo
  final double irrigationNearMaxDelta;

  // Semanas desde siembra para etapa inicial (germinación)
  final int fertilizerInitialStageWeeks;

  // Semanas desde siembra hasta fin de etapa vegetativa
  final int fertilizerVegetativeStageWeeks;

  // Valores canónicos de la configuración del backend (application.properties)
  static const OfflineRuleDefaults fallback = OfflineRuleDefaults();

  factory OfflineRuleDefaults.fromCacheMap(Map<String, String> map) {
    double d(String key, double fallback) =>
        double.tryParse(map[key] ?? '') ?? fallback;
    int i(String key, int fallback) =>
        int.tryParse(map[key] ?? '') ?? fallback;
    return OfflineRuleDefaults(
      phytoTempThreshold: d('phytoTempThreshold', 30.0),
      phytoHumidityThreshold: d('phytoHumidityThreshold', 80.0),
      irrigationNearMaxDelta: d('irrigationNearMaxDelta', 3.0),
      fertilizerInitialStageWeeks: i('fertilizerInitialStageWeeks', 4),
      fertilizerVegetativeStageWeeks: i('fertilizerVegetativeStageWeeks', 12),
    );
  }

  Map<String, String> toMap() => {
    'phytoTempThreshold': phytoTempThreshold.toString(),
    'phytoHumidityThreshold': phytoHumidityThreshold.toString(),
    'irrigationNearMaxDelta': irrigationNearMaxDelta.toString(),
    'fertilizerInitialStageWeeks': fertilizerInitialStageWeeks.toString(),
    'fertilizerVegetativeStageWeeks': fertilizerVegetativeStageWeeks.toString(),
  };
}

// Parámetros agronómicos de referencia para cada tipo de cultivo.
// Réplica de la tabla `crop_parameters` del backend Spring.
// Permite al motor de reglas operar completamente sin conexión.
class CropParameters {
  const CropParameters({
    required this.optimalTempMin,
    required this.optimalTempMax,
    required this.humidityMin,
    required this.humidityMax,
    required this.irrigationNeeds,
    required this.recommendedFertilizer,
    required this.growthCycleDays,
  });

  // Temperatura óptima mínima en °C
  final double optimalTempMin;

  // Temperatura óptima máxima en °C
  final double optimalTempMax;

  // Humedad relativa mínima en %
  final double humidityMin;

  // Humedad relativa máxima en %
  final double humidityMax;

  // Descripción de necesidades de riego
  final String irrigationNeeds;

  // Fertilizante recomendado para el cultivo
  final String recommendedFertilizer;

  // Días del ciclo de crecimiento hasta cosecha
  final int growthCycleDays;
}

// Tabla de parámetros agronómicos por tipo de cultivo.
// Valores sincronizados con la base de datos del backend (crop_parameters).
const Map<CropType, CropParameters> kCropParameters = {
  CropType.BANANO: CropParameters(
    optimalTempMin: 22,
    optimalTempMax: 32,
    humidityMin: 70,
    humidityMax: 90,
    irrigationNeeds: '25–30 L/planta/semana en época seca',
    recommendedFertilizer: 'Formula 15-5-30 + magnesio, cada 6-8 semanas',
    growthCycleDays: 300,
  ),
  CropType.PLATANO: CropParameters(
    optimalTempMin: 22,
    optimalTempMax: 32,
    humidityMin: 70,
    humidityMax: 90,
    irrigationNeeds: '20–25 L/planta/semana en época seca',
    recommendedFertilizer: 'Formula 15-5-30 + magnesio, cada 6-8 semanas',
    growthCycleDays: 360,
  ),
  CropType.MANGO: CropParameters(
    optimalTempMin: 24,
    optimalTempMax: 35,
    humidityMin: 50,
    humidityMax: 80,
    irrigationNeeds: '50–80 L/árbol/semana en floración y cuajado',
    recommendedFertilizer: 'NPK 10-10-10 en vegetativo, alto K en fructificación',
    growthCycleDays: 120,
  ),
  CropType.YUCA: CropParameters(
    optimalTempMin: 25,
    optimalTempMax: 35,
    humidityMin: 50,
    humidityMax: 80,
    irrigationNeeds: '10–15 mm/semana, tolera períodos secos cortos',
    recommendedFertilizer: 'Urea 46% + KCl al momento de siembra, repetir a los 3 meses',
    growthCycleDays: 270,
  ),
  CropType.MAIZ: CropParameters(
    optimalTempMin: 20,
    optimalTempMax: 30,
    humidityMin: 55,
    humidityMax: 80,
    irrigationNeeds: '25–30 mm/semana en floración y llenado de grano',
    recommendedFertilizer: 'Urea en siembra y aporque, DAP al voleo',
    growthCycleDays: 120,
  ),
  CropType.PALMA: CropParameters(
    optimalTempMin: 24,
    optimalTempMax: 33,
    humidityMin: 75,
    humidityMax: 90,
    irrigationNeeds: '150–200 L/palma/semana en época seca',
    recommendedFertilizer: 'Mezcla mineral completa con boro y magnesio, cada 4 meses',
    growthCycleDays: 1095,
  ),
};
