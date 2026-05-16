import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/alerts_api.dart';
import '../../domain/models/alert.dart';

final alertsApiProvider = Provider<AlertsApi>((_) => const AlertsApi());

class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() async {
    final api = ref.read(alertsApiProvider);
    try {
      final page = await api.getAlerts(page: 0, size: 50);
      return page.items;
    } catch (_) {
      return [];
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(alertsApiProvider);
      final page = await api.getAlerts(page: 0, size: 50);
      return page.items;
    });
  }

  Future<void> deleteAlert(String alertId) async {
    final previous = state.value;
    if (previous == null) return;

    final updated = previous.where((a) => a.id != alertId).toList();
    state = AsyncData(updated);

    try {
      await ref.read(alertsApiProvider).deleteAlert(alertId);
      ref.invalidate(alertsUnreadCountProvider);
    } catch (_) {
      state = AsyncData(previous);
    }
  }

  Future<int> deleteAllRead() async {
    final api = ref.read(alertsApiProvider);
    final deleted = await api.deleteAllRead();
    await reload();
    ref.invalidate(alertsUnreadCountProvider);
    return deleted;
  }

  Future<void> markAllVisibleAsRead(List<Alert> alerts) async {
    final api = ref.read(alertsApiProvider);
    for (final alert in alerts) {
      if (!alert.isRead) {
        try {
          await api.markAsRead(alert.id);
        } catch (_) {}
      }
    }
    ref.invalidate(alertsUnreadCountProvider);
  }
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<Alert>>(
  AlertsNotifier.new,
);

/// Filtro activo en la pantalla de alertas (chips superiores).
final alertsFilterProvider = StateProvider<AlertCategory?>((ref) => null);

/// Alertas filtradas por categoria.
final filteredAlertsProvider = Provider<List<Alert>>((ref) {
  final allAsync = ref.watch(alertsProvider);
  final filter = ref.watch(alertsFilterProvider);

  final all = allAsync.value ?? [];
  if (filter == null) return all;
  return all.where((a) => a.category == filter).toList(growable: false);
});

/// Conteo de alertas no leidas (para badge dinamico).
final alertsUnreadCountProvider = FutureProvider<AlertUnreadCount>((ref) async {
  final api = ref.read(alertsApiProvider);
  try {
    return await api.getUnreadCount();
  } catch (_) {
    return const AlertUnreadCount(total: 0, high: 0);
  }
});

/// Tick para forzar recarga de alertas.
final alertsRefreshTickProvider = StateProvider<int>((ref) => 0);
