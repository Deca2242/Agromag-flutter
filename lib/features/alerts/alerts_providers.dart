import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_alerts.dart';
import '../../domain/models/alert.dart';

final alertsProvider = Provider<List<Alert>>((ref) => kMockAlerts);

/// Filtro activo en la pantalla de alertas (chips superiores).
final alertsFilterProvider = StateProvider<AlertCategory?>((ref) => null);

final filteredAlertsProvider = Provider<List<Alert>>((ref) {
  final all = ref.watch(alertsProvider);
  final filter = ref.watch(alertsFilterProvider);
  if (filter == null) return all;
  return all.where((a) => a.category == filter).toList(growable: false);
});
