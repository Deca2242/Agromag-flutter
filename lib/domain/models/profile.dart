import 'package:flutter/foundation.dart';

import 'app_role.dart';
import 'municipality.dart';

/// Modelo de dominio que espeja `ProfileResponse` del backend Spring.
///
/// Reemplaza `UserProfile` (mock) como fuente de verdad sobre el usuario.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.municipality,
    required this.createdAt,
    this.syncedAt,
  });

  final String id;
  final String email;
  final AppRole role;
  final String fullName;
  final Municipality municipality;
  final DateTime createdAt;

  /// Última vez que se sincronizó desde el backend (null = solo caché).
  final DateTime? syncedAt;

  /// Iniciales para el avatar circular del perfil.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Desde la respuesta JSON del backend Spring.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      role: AppRole.fromJson(json['role'] as String),
      fullName: json['fullName'] as String? ?? '',
      municipality: Municipality.fromJson(
        json['municipality'] as String? ?? 'SANTA_MARTA',
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncedAt: DateTime.now(),
    );
  }

  /// Para almacenamiento en SQLite (todos los campos como String).
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'full_name': fullName,
      'municipality': municipality.name,
      'created_at': createdAt.toIso8601String(),
      'synced_at': (syncedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Desde una fila SQLite.
  factory Profile.fromDbMap(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    final email = row['email'] as String?;
    final roleStr = row['role'] as String?;
    final fullName = row['full_name'] as String?;
    final municipalityStr = row['municipality'] as String?;
    final createdAtStr = row['created_at'] as String?;

    if (id == null || email == null || roleStr == null ||
        municipalityStr == null || createdAtStr == null) {
      throw const FormatException('Profile row missing required fields');
    }

    return Profile(
      id: id,
      email: email,
      role: AppRole.fromJson(roleStr),
      fullName: fullName ?? '',
      municipality: Municipality.fromJson(municipalityStr),
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      syncedAt: row['synced_at'] != null
          ? DateTime.tryParse(row['synced_at'] as String)
          : null,
    );
  }

  Profile copyWith({
    String? id,
    String? email,
    AppRole? role,
    String? fullName,
    Municipality? municipality,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      municipality: municipality ?? this.municipality,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
