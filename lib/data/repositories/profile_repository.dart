import 'package:supabase_flutter/supabase_flutter.dart';

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
    final remote = await _api.getProfile();

    Profile profile = remote;

    if (remote.fullName.isEmpty) {
      final metadata =
          _supabase.auth.currentUser?.userMetadata ?? {};
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
          // Si el PUT falla (offline), usamos el remote con fullName vacío
          // por ahora; el usuario podrá editar después.
          profile = remote;
        }
      }
    }

    await _dao.upsert(profile);
    return profile;
  }

  /// Retorna el perfil del caché SQLite (para arranque offline o pantalla
  /// de inicio mientras se espera la red).
  Future<Profile?> getCachedProfile({String? userId}) async {
    if (userId != null) return _dao.find(userId);
    return _dao.findAny();
  }

  /// Actualiza el perfil en el backend y reflesce el cambio en SQLite.
  Future<Profile> updateProfile({
    required String fullName,
    required Municipality municipality,
  }) async {
    final updated = await _api.updateProfile(
      fullName: fullName,
      municipality: municipality,
    );
    await _dao.upsert(updated);
    return updated;
  }

  /// Limpia el caché de perfil al cerrar sesión.
  Future<void> clearLocalProfile() async {
    await _dao.clear();
  }
}
