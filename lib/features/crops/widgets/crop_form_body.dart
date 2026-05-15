import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/municipality.dart';

/// Formulario reutilizable para crear y editar cultivos.
class CropFormBody extends StatelessWidget {
  const CropFormBody({
    super.key,
    required this.areaCtrl,
    required this.cropType,
    required this.municipality,
    required this.sownDate,
    required this.onCropTypeChanged,
    required this.onMunicipalityChanged,
    required this.onDateChanged,
  });

  final TextEditingController areaCtrl;
  final CropType? cropType;
  final Municipality? municipality;
  final DateTime? sownDate;
  final ValueChanged<CropType?> onCropTypeChanged;
  final ValueChanged<Municipality?> onMunicipalityChanged;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IdentificationCard(
          cropType: cropType,
          onCropTypeChanged: onCropTypeChanged,
        ),
        const SizedBox(height: 16),
        _TerrainCard(
          areaCtrl: areaCtrl,
          municipality: municipality,
          onMunicipalityChanged: onMunicipalityChanged,
        ),
        const SizedBox(height: 16),
        _DateCard(sownDate: sownDate, onDateChanged: onDateChanged),
      ],
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({
    required this.cropType,
    required this.onCropTypeChanged,
  });

  final CropType? cropType;
  final ValueChanged<CropType?> onCropTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.eco, label: 'Identificación'),
          const SizedBox(height: 14),
          const _FieldLabel('Tipo de cultivo *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<CropType>(
            initialValue: cropType,
            decoration: const InputDecoration(hintText: 'Selecciona un tipo'),
            items: CropType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: onCropTypeChanged,
            validator: (v) =>
                v == null ? 'Selecciona el tipo de cultivo.' : null,
          ),
        ],
      ),
    );
  }
}

class _TerrainCard extends StatelessWidget {
  const _TerrainCard({
    required this.areaCtrl,
    required this.municipality,
    required this.onMunicipalityChanged,
  });

  final TextEditingController areaCtrl;
  final Municipality? municipality;
  final ValueChanged<Municipality?> onMunicipalityChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.terrain, label: 'Detalles del Terreno'),
          const SizedBox(height: 14),
          const _FieldLabel('Área (Hectáreas) *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: areaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(hintText: 'Ej: 2.5'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa el área.';
              final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                return 'Ingresa un valor mayor a 0.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Municipio *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<Municipality>(
            initialValue: municipality,
            decoration: const InputDecoration(
              hintText: 'Selecciona un municipio',
            ),
            isExpanded: true,
            items: Municipality.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: onMunicipalityChanged,
            validator: (v) => v == null ? 'Selecciona el municipio.' : null,
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.sownDate, required this.onDateChanged});

  final DateTime? sownDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha de Siembra',
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Fecha de siembra *'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: sownDate ?? now,
                firstDate: DateTime(2000),
                lastDate: now,
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
                      sownDate == null
                          ? 'Seleccionar fecha'
                          : DateFormat('dd/MM/yyyy').format(sownDate!),
                      style: TextStyle(
                        color: sownDate == null
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.label});
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}
