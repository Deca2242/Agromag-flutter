import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../crops/crops_providers.dart';
import '../home_providers.dart';

/// Dispara riego + fertilización + fitosanitario y refresca listas de Inicio y detalle.
/// Cuando hay conexión usa el backend (IA + reglas).
/// Cuando no hay conexión usa el motor de reglas local con clima cacheado.
class GenerateRecommendationsButton extends ConsumerStatefulWidget {
  const GenerateRecommendationsButton({super.key, required this.cropId});

  final String cropId;

  @override
  ConsumerState<GenerateRecommendationsButton> createState() =>
      _GenerateRecommendationsButtonState();
}

class _GenerateRecommendationsButtonState
    extends ConsumerState<GenerateRecommendationsButton> {
  bool _generating = false;
  String? _error;

  Future<void> _onGenerate() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    final isOnline = ref.read(isOnlineProvider).value ?? true;

    try {
      if (isOnline) {
        await _generateOnline();
      } else {
        await _generateOffline();
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _generateOnline() async {
    final api = ref.read(recommendationsApiProvider);
    try {
      await Future.wait([
        api.generateIrrigation(widget.cropId),
        api.generateFertilizer(widget.cropId),
        api.generatePhytosanitary(widget.cropId),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Tiempo de espera agotado'),
      );
      _refreshProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recomendaciones generadas exitosamente.'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron generar las recomendaciones.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!), backgroundColor: AppColors.alertRed),
        );
      }
    }
  }

  Future<void> _generateOffline() async {
    final crop = await ref.read(cropByIdProvider(widget.cropId).future);
    if (crop == null) {
      if (mounted) {
        setState(
          () => _error =
              'No se encontró información del cultivo de forma local.',
        );
      }
      return;
    }

    final repo = ref.read(recommendationsRepositoryProvider);
    final results = await repo.generateOffline(crop);

    if (!mounted) return;

    _refreshProviders();
    // Si alguna recomendación es de tipo OPTIMAL sin datos de clima, informar al usuario
    final hasPartialData = results.any(
      (r) =>
          r.body.contains('datos de clima') ||
          r.body.contains('clima en caché'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPartialData
              ? 'Recomendaciones generadas (sin datos de clima actualizados).'
              : 'Recomendaciones generadas (modo sin internet).',
        ),
        backgroundColor: AppColors.warningBrown,
      ),
    );
  }

  void _refreshProviders() {
    ref.invalidate(cropRecommendationsProvider(widget.cropId));
    ref.invalidate(dashboardRecommendationsProvider);
    ref
        .read(recommendationHistoryTickProvider(widget.cropId).notifier)
        .state++;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _generating ? null : _onGenerate,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                )
              : Icon(
                  isOnline
                      ? Icons.auto_awesome_outlined
                      : Icons.offline_bolt_outlined,
                  size: 18,
                ),
          label: Text(
            _generating
                ? 'Generando recomendaciones…'
                : isOnline
                ? 'Generar recomendaciones'
                : 'Generar recomendaciones (sin internet)',
          ),
        ),
        if (!isOnline && !_generating && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Se usarán reglas agronómicas y clima en caché.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.alertRed, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
