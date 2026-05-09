import 'package:flutter/material.dart';

import '../../domain/models/alert.dart';

final List<Alert> kMockAlerts = [
  Alert(
    id: 'broca',
    title: 'Brote de Broca',
    description:
        'Se detectó alta incidencia de broca en el sector norte. '
        'Aplicación requerida urgente.',
    timestamp: 'Hace 2 horas',
    category: AlertCategory.phytosanitary,
    severity: AlertSeverity.high,
    cropTag: 'Café - Lote A',
    iconCodePoint: Icons.bug_report.codePoint,
  ),
  Alert(
    id: 'deficit-hidrico',
    title: 'Déficit Hídrico',
    description:
        'Niveles de humedad del suelo por debajo del óptimo. '
        'Considere iniciar ciclo de riego.',
    timestamp: 'Ayer, 14:30',
    category: AlertCategory.irrigation,
    severity: AlertSeverity.medium,
    cropTag: 'Plátano - Lote C',
    iconCodePoint: Icons.water_drop.codePoint,
  ),
  Alert(
    id: 'recordatorio-fertilizacion',
    title: 'Recordatorio Fertilización',
    description:
        'Programado ciclo de fertilización nitrogenada para la '
        'próxima semana.',
    timestamp: '12 Oct, 08:00',
    category: AlertCategory.fertilization,
    severity: AlertSeverity.info,
    cropTag: 'Cacao - Lote B',
    iconCodePoint: Icons.eco.codePoint,
  ),
];
