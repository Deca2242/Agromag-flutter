import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/services/local_db.dart';
import '../../../data/services/profile_api.dart';
import '../../../data/services/profile_local_dao.dart';
import '../../../domain/models/app_role.dart';
import '../../../domain/models/municipality.dart';
import '../../../domain/models/profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => const AuthRepository(),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => const ProfileRepository(api: ProfileApi(), dao: ProfileLocalDao()),
);

/// Emite la sesión actual cada vez que cambia (login, logout, refresh).
final authSessionProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session,
  );
});

/// Intenta primero el caché SQLite; si hay sesión activa, sincroniza con el
/// backend en segundo plano y refresca el estado.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final sessionAsync = ref.watch(authSessionProvider);
  final session = sessionAsync.value;

  if (session == null) return null;

  final profileRepo = ref.read(profileRepositoryProvider);

  final cached = await profileRepo.getCachedProfile(userId: session.user.id);
  if (cached != null) {
    unawaited(
      profileRepo.bootstrapAfterSignIn()
          .timeout(const Duration(seconds: 15))
          .then((_) => ref.invalidateSelf())
          .catchError((_) {}),
    );
    return cached;
  }

  try {
    return await profileRepo.bootstrapAfterSignIn().timeout(
      const Duration(seconds: 15),
    );
  } catch (_) {
    final u = session.user;
    final meta = u.userMetadata ?? {};
    Municipality fallbackMunicipality;
    try {
      final m = meta['municipality'];
      fallbackMunicipality = m != null
          ? Municipality.fromJson(m as String)
          : Municipality.SANTA_MARTA;
    } catch (_) {
      fallbackMunicipality = Municipality.SANTA_MARTA;
    }
    final fallbackProfile = Profile(
      id: u.id,
      email: u.email ?? '',
      role: AppRole.PRODUCER,
      fullName: meta['full_name'] as String? ?? '',
      municipality: fallbackMunicipality,
      createdAt: DateTime.tryParse(u.createdAt) ?? DateTime.now(),
    );
    await profileRepo.getCachedProfile(userId: u.id).then((existing) async {
      if (existing == null) {
        final dao = ProfileLocalDao();
        await dao.upsert(fallbackProfile);
      }
    });
    return fallbackProfile;
  }
});

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _auth.signIn(email: email, password: password),
    );
    if (state.hasError) return;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required Municipality municipality,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _auth.signUp(
        email: email,
        password: password,
        fullName: fullName,
        municipality: municipality,
      ),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await LocalDb.instance.clearUserData();
    await _auth.signOut();
    state = const AsyncData(null);
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _auth.resetPassword(email));
  }

  /// Mensaje de error legible para el usuario final.
  String? get errorMessage {
    final err = state.error;
    if (err == null) return null;
    if (err is NetworkException) {
      return 'Sin conexión. Para entrar con correo y contraseña necesitas '
          'internet al menos una vez. Si ya entraste antes, cierra y abre la '
          'app: la sesión guardada puede aparecer tras unos segundos.';
    }
    if (err is AuthException) return _mapAuthError(err.message);
    if (err is ApiException) return err.message;
    return 'Error inesperado. Intenta de nuevo.';
  }

  String _mapAuthError(String supabaseMessage) {
    final msg = supabaseMessage.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (msg.contains('password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return supabaseMessage;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
