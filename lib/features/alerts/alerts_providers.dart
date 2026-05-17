import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/alerts_api.dart';
import '../../domain/models/alert.dart';

final alertsApiProvider = Provider<AlertsApi>((_) => const AlertsApi());

class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() async {
    final api = ref.read(alertsApiProvider);
    final page = await api.getAlerts(page: 0, size: 50);
    return page.items;
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

  Future<void> markAsRead(String alertId) async {
    final previous = state.value;
    if (previous == null) return;

    final updated = previous
        .map((a) => a.id == alertId ? a.copyWith(isRead: true) : a)
        .toList(growable: false);
    state = AsyncData(updated);

    try {
      await ref.read(alertsApiProvider).markAsRead(alertId);
      ref.invalidate(alertsUnreadCountProvider);
    } catch (_) {
      state = AsyncData(previous);
    }
  }

  Future<int> markAllAsRead() async {
    final previous = state.value;
    final api = ref.read(alertsApiProvider);
    final updatedCount = await api.markAllAsRead();
    if (previous != null) {
      state = AsyncData(
        previous.map((a) => a.copyWith(isRead: true)).toList(growable: false),
      );
    }
    ref.invalidate(alertsUnreadCountProvider);
    return updatedCount;
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

final alertsFilterProvider = StateProvider<AlertCategory?>((ref) => null);

final filteredAlertsProvider = Provider<List<Alert>>((ref) {
  final allAsync = ref.watch(alertsProvider);
  final filter = ref.watch(alertsFilterProvider);

  final all = allAsync.value ?? [];
  if (filter == null) return all;
  return all.where((a) => a.category == filter).toList(growable: false);
});

final alertsUnreadCountProvider = FutureProvider<AlertUnreadCount>((ref) async {
  final api = ref.read(alertsApiProvider);
  try {
    return await api.getUnreadCount();
  } catch (_) {
    return const AlertUnreadCount(total: 0, high: 0);
  }
});

final alertsRefreshTickProvider = StateProvider<int>((ref) => 0);
