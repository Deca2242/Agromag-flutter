import '../../domain/models/recommendation.dart';

/// Recomendaciones pendientes de decisión (`followed == null`) para un tipo.
List<Recommendation> activeByType(
  List<Recommendation> all,
  RecommendationType type, {
  int maxItems = 5,
}) {
  final list = all.where((r) => r.type == type && r.followed == null).toList();
  list.sort((a, b) {
    final da = a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  if (list.length <= maxItems) return list;
  return list.sublist(0, maxItems);
}

/// Recomendaciones con decisión del usuario, más recientes primero.
List<Recommendation> historyDecided(List<Recommendation> all) {
  final list = all.where((r) => r.followed != null).toList();
  list.sort((a, b) {
    final da = a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return list;
}
