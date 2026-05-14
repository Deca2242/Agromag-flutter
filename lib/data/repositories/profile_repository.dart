import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handling.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/profile.dart';
import '../services/profile_api.dart';
import '../services/profile_local_dao.dart';

/// Orquesta datos de perfil entre el backend Spring y SQLite local.
class ProfileRepository {
  const ProfileRepository({
    required ProfileApi api,
    required ProfileLocalDao dao,
  })  : _api = api,
        _dao = dao;

  final ProfileApi _api;
  final ProfileLocalDao _dao;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Llama a `GET /api/profile` tras el sign-in para:
  ///
  ///  1. Autoprovisionar la fila de Profile en el backend (si es un usuario nuevo).
  ///  2. Completar `fullName` y `municipality` desde `user_metadata` si el
  ///     perfil se creó con datos vacíos (primer login tras registro).
  ///  3. Persiste el resultado en SQLite.
  Future<Profile> bootstrapAfterSignIn() async {
    final profile = await _fetchRemoteProfileMerged();
    await _dao.upsert(profile);
    return profile;
  }

  /// Descarga el perfil desde el servidor y lo guarda en SQLite (sync manual / pull).
  Future<void> refreshFromServer() async {
    final profile = await _fetchRemoteProfileMerged();
    await _dao.upsert(profile);
  }

  Future<Profile> _fetchRemoteProfileMerged() async {
    final remote = await _api.getProfile();

    Profile profile = remote;

    if (remote.fullName.isEmpty) {
      final metadata = _supabase.auth.currentUser?.userMetadata ?? {};
      final fullName = metadata['full_name'] as String?;
      final municipalityStr = metadata['municipality'] as String?;

      if (fullName != null && fullName.isNotEmpty) {
        final municipality = municipalityStr != null
            ? Municipality.fromJson(municipalityStr)
            : Municipality.SANTA_MARTA;

        try {
          profile = await _api.updateProfile(
            fullName: fullName,
            municipality: municipality,
          );
        } catch (_) {
          profile = remote;
        }
      }
    }

    return profile;
  }

  /// Retorna el perfil del caché SQLite.
  Future<Profile?> getCachedProfile({String? userId}) async {
    if (userId != null) return _dao.find(userId);
    return _dao.findAny();
  }

  /// Actualiza el perfil offline-first:
  /// - Si hay red → PUT /api/profile y persiste resultado.
  /// - Si no hay red → guarda localmente con pending_update=true.
  Future<Profile> updateProfile({
    required String fullName,
    required Municipality municipality,
  }) async {
    final current = await _dao.findAny();
    final optimistic =
        current?.copyWith(fullName: fullName, municipality: municipality) ??
            Profile(
              id: '',
              email: '',
              role: current?.role ?? (throw StateError('No profile in cache')),
              fullName: fullName,
              municipality: municipality,
              createdAt: DateTime.now(),
            );

    try {
      final updated = await _api.updateProfile(
        fullName: fullName,
        municipality: municipality,
      );
      await _dao.upsert(updated);
      return updated;
    } on NetworkException {
      await _dao.upsert(optimistic, pendingUpdate: true);
      return optimistic;
    }
  }

  /// Sube al backend cualquier actualización de perfil guardada mientras
  /// estaba sin conexión. Se llama al detectar reconexión.
  ///
  /// Retorna `false` si había pendiente y falló la subida.
  Future<bool> syncPendingProfile() async {
    final pending = await _dao.findPendingUpdate();
    if (pending == null) return true;
    try {
      final updated = await _api.updateProfile(
        fullName: pending.fullName,
        municipality: pending.municipality,
      );
      await _dao.upsert(updated);
      return true;
    } catch (error, stackTrace) {
      AppErrorHandling.report('profile_sync_pending_failed', error, stackTrace);
      return false;
    }
  }

  /// `true` si hay cambios de perfil pendientes de subir al servidor.
  Future<bool> hasPendingProfileUpdate() async =>
      (await _dao.findPendingUpdate()) != null;

  /// Limpia el caché de perfil al cerrar sesión.
  Future<void> clearLocalProfile() async {
    await _dao.clear();
  }
}
