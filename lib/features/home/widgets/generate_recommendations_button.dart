import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../home_providers.dart';

/// Dispara riego + fertilización + fitosanitario y refresca listas de Inicio y detalle.
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
      ref.invalidate(cropRecommendationsProvider(widget.cropId));
      ref.invalidate(dashboardRecommendationsProvider);
      ref
          .read(recommendationHistoryTickProvider(widget.cropId).notifier)
          .state++;
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
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              : const Icon(Icons.auto_awesome_outlined, size: 18),
          label: Text(
            _generating
                ? 'Generando recomendaciones…'
                : 'Generar recomendaciones',
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
