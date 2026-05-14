import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/recommendation.dart';
import '../../../domain/models/sync_status.dart';
import '../../../domain/models/weather.dart';
import '../../home/home_providers.dart';
import '../../home/weather_providers.dart';
import '../../home/widgets/generate_recommendations_button.dart';
import '../../home/widgets/recommendation_tile.dart';
import '../../sync/sync_coordinator.dart';
import '../crops_providers.dart';
import '../recommendation_filters.dart';
import '../widgets/plan_expansion_tile.dart';
import '../widgets/task_history_tile.dart';

Future<void> _openRecommendationDecision(
  BuildContext context,
  WidgetRef ref, {
  required Recommendation recommendation,
  required String cropId,
  required bool online,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              recommendation.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(recommendationsRepositoryProvider)
                      .submitDecision(
                        recommendationId: recommendation.id,
                        followed: true,
                      );
                  ref.invalidate(cropRecommendationsProvider(cropId));
                  ref.invalidate(dashboardRecommendationsProvider);
                  ref
                      .read(recommendationHistoryTickProvider(cropId).notifier)
                      .state++;
                  ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo guardar la decisión.'),
                        backgroundColor: AppColors.alertRed,
                      ),
                    );
                  }
                }
              },
              child: Text(
                online ? 'Realizado' : 'Realizado (offline)',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(recommendationsRepositoryProvider)
                      .submitDecision(
                        recommendationId: recommendation.id,
                        followed: false,
                      );
                  ref.invalidate(cropRecommendationsProvider(cropId));
                  ref.invalidate(dashboardRecommendationsProvider);
                  ref
                      .read(recommendationHistoryTickProvider(cropId).notifier)
                      .state++;
                  ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo guardar la decisión.'),
                        backgroundColor: AppColors.alertRed,
                      ),
                    );
                  }
                }
              },
              child: Text(
                online ? 'Rechazado' : 'Rechazado (offline)',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.cropId});

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropAsync = ref.watch(cropByIdProvider(cropId));
    final online = ref.watch(isOnlineProvider).value ?? true;

    return cropAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: const Center(child: Text('Error al cargar el cultivo.')),
      ),
      data: (crop) {
        if (crop == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: const Center(child: Text('Cultivo no encontrado.')),
          );
        }
        return _DetailContent(crop: crop, online: online);
      },
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.crop, required this.online});

  final Crop crop;
  final bool online;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Crop crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cultivo'),
        content: Text(
          '¿Seguro que quieres eliminar "${crop.cropType.label}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.alertRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(cropsRepositoryProvider).deleteCrop(crop.id);
    ref.invalidate(cropsProvider);
    ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();

    if (context.mounted) {
      final isOnline = ref.read(isOnlineProvider).value ?? true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Cultivo eliminado.'
                : 'Eliminado localmente. Se sincronizará al reconectar.',
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentWeatherProvider(crop.municipality));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            BrandLogo(size: 24),
            SizedBox(width: 8),
            Text(
              'Detalle de Cultivo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!online)
              const OfflineBanner(
                message: 'Modo sin conexión. Datos guardados localmente.',
              ),
            Expanded(
              child: AdaptiveBody(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _Header(crop: crop),
                    const SizedBox(height: 16),
                    _ClimateCard(weatherAsync: weatherAsync, crop: crop, ref: ref),
                    const SizedBox(height: 24),
                    Text(
                      'Planes Activos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _CropPlansFromRecommendations(crop: crop, online: online),
                    const SizedBox(height: 24),
                    Text(
                      'Recomendaciones',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Genera recomendaciones de riego, fertilización y '
                      'fitosanitarios. Las pendientes aparecen en cada plan activo.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (online)
                      GenerateRecommendationsButton(cropId: crop.id),
                    const SizedBox(height: 24),
                    Text(
                      'Historial de decisiones',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _RecommendationDecisionsHistorySection(
                      cropId: crop.id,
                      online: online,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/crops/${crop.id}/edit',
                        extra: crop,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar cultivo'),
                    ),
                    const SizedBox(height: 10),
                    DangerButton(
                      label: 'Eliminar cultivo',
                      icon: Icons.delete_outline,
                      onPressed: () => _confirmDelete(context, ref, crop),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPlansFromRecommendations extends ConsumerWidget {
  const _CropPlansFromRecommendations({
    required this.crop,
    required this.online,
  });

  final Crop crop;
  final bool online;

  List<Widget> _tilesForType(
    BuildContext context,
    WidgetRef ref,
    List<Recommendation> recs,
    RecommendationType type,
  ) {
    final active = activeByType(recs, type);
    if (active.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Sin recomendaciones pendientes.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    return [
      for (final r in active) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: RecommendationTile(
            recommendation: r,
            onTap: () => _openRecommendationDecision(
              context,
              ref,
              recommendation: r,
              cropId: crop.id,
              online: online,
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cropRecommendationsProvider(crop.id));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'No se pudieron cargar las recomendaciones.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (recs) {
        return Column(
          children: [
            PlanExpansionTile(
              title: 'Riego',
              icon: Icons.water_drop,
              iconColor: AppColors.primaryGreen,
              iconBackground: AppColors.softGreenBg,
              subtitle: activeByType(recs, RecommendationType.irrigation).isEmpty
                  ? null
                  : 'Recomendaciones activas',
              children: _tilesForType(
                context,
                ref,
                recs,
                RecommendationType.irrigation,
              ),
            ),
            const SizedBox(height: 10),
            PlanExpansionTile(
              title: 'Fertilización',
              icon: Icons.eco,
              iconColor: const Color(0xFF8A4B00),
              iconBackground: const Color(0xFFF6E7D7),
              subtitle: activeByType(recs, RecommendationType.fertilizer).isEmpty
                  ? null
                  : 'Recomendaciones activas',
              children: _tilesForType(
                context,
                ref,
                recs,
                RecommendationType.fertilizer,
              ),
            ),
            const SizedBox(height: 10),
            PlanExpansionTile(
              title: 'Fitosanitario',
              icon: Icons.bug_report,
              iconColor: AppColors.alertRed,
              iconBackground: AppColors.alertRedSoft,
              subtitle:
                  activeByType(recs, RecommendationType.phytosanitary).isEmpty
                      ? null
                      : 'Recomendaciones activas',
              children: _tilesForType(
                context,
                ref,
                recs,
                RecommendationType.phytosanitary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecommendationDecisionsHistorySection extends ConsumerStatefulWidget {
  const _RecommendationDecisionsHistorySection({
    required this.cropId,
    required this.online,
  });

  final String cropId;
  final bool online;

  @override
  ConsumerState<_RecommendationDecisionsHistorySection> createState() =>
      _RecommendationDecisionsHistorySectionState();
}

class _RecommendationDecisionsHistorySectionState
    extends ConsumerState<_RecommendationDecisionsHistorySection> {
  final List<Recommendation> _items = <Recommendation>[];
  int _nextPageToFetch = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadInitial());
    });
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextPageToFetch = 0;
      _hasMore = true;
    });
    await _fetchNext(isInitial: true);
  }

  Future<void> _fetchNext({required bool isInitial}) async {
    final pageNum = isInitial ? 0 : _nextPageToFetch;
    try {
      final page = await ref.read(recommendationsApiProvider).listByCropPaged(
            widget.cropId,
            followedFilter: 'decided',
            page: pageNum,
            size: 3,
          );
      if (!mounted) return;
      setState(() {
        if (isInitial) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          for (final r in page.items) {
            if (!_items.any((e) => e.id == r.id)) {
              _items.add(r);
            }
          }
        }
        _hasMore = page.hasNextPage;
        _nextPageToFetch = page.pageNumber + 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el historial.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    await _fetchNext(isInitial: false);
  }

  String _bodyPreview(String body) {
    if (body.length <= 120) return body;
    return '${body.substring(0, 117)}…';
  }

  Future<void> _confirmReset(Recommendation r) async {
    if (!widget.online || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular decisión'),
        content: const Text(
          'Volverá a aparecer como recomendación pendiente. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(recommendationsApiProvider).resetDecision(r.id);
      ref.invalidate(cropRecommendationsProvider(widget.cropId));
      ref.invalidate(dashboardRecommendationsProvider);
      await _loadInitial();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo anular la decisión.'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      recommendationHistoryTickProvider(widget.cropId),
      (prev, next) {
        if (prev != null && prev != next) {
          unawaited(_loadInitial());
        }
      },
    );

    if (_loading && _items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Text(
        _error!,
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }

    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Aún no registras decisiones sobre recomendaciones.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.divider),
                TaskHistoryTile(
                  title: _items[i].title,
                  subtitle:
                      '${_items[i].followed == true ? "Realizado" : "Rechazado"} · '
                      '${_bodyPreview(_items[i].body)}',
                  when: DateFormat('dd/MM/yyyy HH:mm').format(
                    _items[i].generatedAt ?? DateTime.now(),
                  ),
                  trailing: widget.online
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onSelected: (v) {
                            if (v == 'reset') {
                              unawaited(_confirmReset(_items[i]));
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem<String>(
                              value: 'reset',
                              child: Text('Anular decisión'),
                            ),
                          ],
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (_hasMore) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadingMore ? null : () => unawaited(_loadMore()),
            icon: _loadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(_loadingMore ? 'Cargando…' : 'Cargar más'),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: crop.cropType.iconBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            crop.cropType.emoji,
            style: const TextStyle(fontSize: 32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      crop.cropType.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _SyncBadge(status: crop.syncStatus),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      crop.municipality.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Siembra: ${df.format(crop.sownDate)}',
                    style: const TextStyle(
                      color: AppColors.primaryGreenDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.terrain,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${crop.areaHectares} ha',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClimateCard extends StatelessWidget {
  const _ClimateCard({
    required this.weatherAsync,
    required this.crop,
    required this.ref,
  });

  final AsyncValue<CurrentWeather> weatherAsync;
  final Crop crop;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clima en el lote',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                weatherAsync.when(
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  error: (_, _) => const Text(
                    '--°C',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                  data: (w) => Text(
                    w.temperatureLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                ),
                const Text(
                  'Open-Meteo',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (weatherAsync.hasError)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    ref.invalidate(
                      currentWeatherProvider(crop.municipality),
                    );
                    ref.invalidate(
                      weatherDataProvider(crop.municipality),
                    );
                  },
                )
              else
                const Icon(
                  Icons.wb_cloudy,
                  size: 44,
                  color: Colors.white,
                ),
              const SizedBox(height: 12),
              Text(
                weatherAsync.maybeWhen(
                  data: (w) => 'Humedad: ${w.humidityLabel}',
                  orElse: () => 'Humedad: --%',
                ),
                style: const TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () => context.pushNamed(
                  AppRoutes.homeWeatherName,
                  extra: crop.municipality,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ver detalle del clima'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.SYNCED => const Icon(
          Icons.cloud_done_outlined,
          size: 18,
          color: AppColors.primaryGreen,
        ),
      SyncStatus.PENDING => const Icon(
          Icons.cloud_upload_outlined,
          size: 18,
          color: AppColors.warningAmber,
        ),
      SyncStatus.ERROR => const Icon(
          Icons.cloud_off,
          size: 18,
          color: AppColors.alertRed,
        ),
    };
  }
}
