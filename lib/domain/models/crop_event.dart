import 'package:flutter/material.dart';

// ignore_for_file: constant_identifier_names
enum EventType {
  IRRIGATION,
  FERTILIZER,
  PESTICIDE,
  FUNGICIDE,
  OBSERVATION;

  String get label => switch (this) {
    EventType.IRRIGATION => 'Riego',
    EventType.FERTILIZER => 'Fertilización',
    EventType.PESTICIDE => 'Pesticida',
    EventType.FUNGICIDE => 'Fungicida',
    EventType.OBSERVATION => 'Observación',
  };

  IconData get icon => switch (this) {
    EventType.IRRIGATION => Icons.water_drop_outlined,
    EventType.FERTILIZER => Icons.eco_outlined,
    EventType.PESTICIDE => Icons.bug_report_outlined,
    EventType.FUNGICIDE => Icons.science_outlined,
    EventType.OBSERVATION => Icons.visibility_outlined,
  };

  static EventType fromJson(String s) {
    return EventType.values.firstWhere(
      (e) => e.name == s.toUpperCase(),
      orElse: () => EventType.OBSERVATION,
    );
  }
}

class CropEvent {
  const CropEvent({
    required this.id,
    required this.cropId,
    required this.eventType,
    required this.occurredAt,
    this.notes,
    this.quantity,
    this.unit,
    this.synced = true,
    this.pendingDelete = false,
  });

  final String id;
  final String cropId;
  final EventType eventType;
  final DateTime occurredAt;
  final String? notes;
  final double? quantity;
  final String? unit;
  final bool synced;
  final bool pendingDelete;

  factory CropEvent.fromJson(Map<String, dynamic> json) {
    return CropEvent(
      id: json['id'] as String,
      cropId: json['cropId'] as String,
      eventType: EventType.fromJson(json['eventType'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      notes: json['notes'] as String?,
      quantity: json['quantity'] != null
          ? (json['quantity'] as num).toDouble()
          : null,
      unit: json['unit'] as String?,
      synced: true,
      pendingDelete: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cropId': cropId,
      'eventType': eventType.name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      'occurredAt': occurredAt.toIso8601String().replaceFirst(
        RegExp(r'\..*'),
        '',
      ),
    };
  }

  CropEvent copyWith({
    String? id,
    String? cropId,
    EventType? eventType,
    DateTime? occurredAt,
    String? notes,
    double? quantity,
    String? unit,
    bool? synced,
    bool? pendingDelete,
  }) {
    return CropEvent(
      id: id ?? this.id,
      cropId: cropId ?? this.cropId,
      eventType: eventType ?? this.eventType,
      occurredAt: occurredAt ?? this.occurredAt,
      notes: notes ?? this.notes,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      synced: synced ?? this.synced,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }
}
