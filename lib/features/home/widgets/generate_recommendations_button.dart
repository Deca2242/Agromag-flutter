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

  Future<void> _onGenerate() async {
    setState(() => _generating = true);
    final api = ref.read(recommendationsApiProvider);
    try {
      await Future.wait([
        api.generateIrrigation(widget.cropId),
        api.generateFertilizer(widget.cropId),
        api.generatePhytosanitary(widget.cropId),
      ]);
      ref.invalidate(cropRecommendationsProvider(widget.cropId));
      ref.invalidate(dashboardRecommendationsProvider);
      ref
          .read(recommendationHistoryTickProvider(widget.cropId).notifier)
          .state++;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al generar recomendaciones.'),
            backgroundColor: AppColors.alertRed,
          ),
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
    return OutlinedButton.icon(
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
      label: Text(_generating ? 'Generando…' : 'Generar recomendaciones'),
    );
  }
}
