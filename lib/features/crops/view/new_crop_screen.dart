import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/mock/mock_crops.dart';

class NewCropScreen extends StatefulWidget {
  const NewCropScreen({super.key});

  @override
  State<NewCropScreen> createState() => _NewCropScreenState();
}

class _NewCropScreenState extends State<NewCropScreen> {
  String? _cropType;
  String? _soilType;
  String? _irrigationSystem;
  DateTime? _plantedAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
              'AgroMagdalena',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cloud_off, color: AppColors.alertRed),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Nuevo Cultivo',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Registra los detalles de tu nueva siembra para llevar '
                'un control preciso.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _IdentificationCard(
                cropType: _cropType,
                onCropTypeChanged: (v) => setState(() => _cropType = v),
              ),
              const SizedBox(height: 16),
              _TerrainCard(
                soilType: _soilType,
                onSoilTypeChanged: (v) => setState(() => _soilType = v),
              ),
              const SizedBox(height: 16),
              _ManagementCard(
                irrigationSystem: _irrigationSystem,
                plantedAt: _plantedAt,
                onIrrigationChanged: (v) =>
                    setState(() => _irrigationSystem = v),
                onDateChanged: (d) => setState(() => _plantedAt = d),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Guardar cultivo',
                icon: Icons.save_outlined,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.sync,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se guardará localmente aunque no tengas conexión',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({
    required this.cropType,
    required this.onCropTypeChanged,
  });

  final String? cropType;
  final ValueChanged<String?> onCropTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.eco, label: 'Identificación'),
          const SizedBox(height: 14),
          const _Label('Nombre personalizado'),
          const SizedBox(height: 6),
          const TextField(
            decoration: InputDecoration(hintText: 'Ej: Lote San Juan'),
          ),
          const SizedBox(height: 14),
          const _Label('Tipo de cultivo'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: cropType,
            decoration: const InputDecoration(hintText: 'Selecciona un tipo'),
            items: kCropTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: onCropTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _TerrainCard extends StatelessWidget {
  const _TerrainCard({
    required this.soilType,
    required this.onSoilTypeChanged,
  });

  final String? soilType;
  final ValueChanged<String?> onSoilTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.terrain, label: 'Detalles del Terreno'),
          const SizedBox(height: 14),
          const _Label('Área (Hectáreas)'),
          const SizedBox(height: 6),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '0.0'),
          ),
          const SizedBox(height: 14),
          const _Label('Ubicación'),
          const SizedBox(height: 6),
          TextField(
            decoration: InputDecoration(
              hintText: 'Sector o Vereda',
              suffixIcon: Semantics(
                label: 'Detectar ubicación con GPS',
                button: true,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.gps_fixed,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Label('Tipo de suelo'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: soilType,
            decoration: const InputDecoration(hintText: 'Selecciona un tipo'),
            items: kSoilTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: onSoilTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.irrigationSystem,
    required this.plantedAt,
    required this.onIrrigationChanged,
    required this.onDateChanged,
  });

  final String? irrigationSystem;
  final DateTime? plantedAt;
  final ValueChanged<String?> onIrrigationChanged;
  final ValueChanged<DateTime> onDateChanged;

  String _formatDate() {
    if (plantedAt == null) return 'mm/dd/yyyy';
    final m = plantedAt!.month.toString().padLeft(2, '0');
    final d = plantedAt!.day.toString().padLeft(2, '0');
    return '$m/$d/${plantedAt!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            icon: Icons.water_drop_outlined,
            label: 'Manejo y Fechas',
          ),
          const SizedBox(height: 14),
          const _Label('Sistema de riego'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: irrigationSystem,
            decoration:
                const InputDecoration(hintText: 'Selecciona un sistema'),
            items: kIrrigationSystems
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: onIrrigationChanged,
          ),
          const SizedBox(height: 14),
          const _Label('Fecha de siembra'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: plantedAt ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(),
                      style: TextStyle(
                        color: plantedAt == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
