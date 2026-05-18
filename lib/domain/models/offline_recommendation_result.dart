import 'recommendation.dart';

// Resultado producido por el motor de reglas offline.
// Contiene toda la información necesaria para construir un Recommendation local.
class OfflineRecommendationResult {
  const OfflineRecommendationResult({
    required this.type,
    required this.level,
    required this.message,
    required this.generatedAt,
    this.suspectedPests,
  });

  final RecommendationType type;
  final RecommendationLevel level;
  final String message;
  final DateTime generatedAt;

  // Solo presente en resultados fitosanitarios
  final String? suspectedPests;
}
