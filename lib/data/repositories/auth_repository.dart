import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_exceptions.dart';
import '../../domain/models/municipality.dart';

/// Abstrae todas las operaciones de autenticación sobre Supabase Auth.
class AuthRepository {
  const AuthRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// Registra un nuevo usuario en Supabase.
  ///
  /// `fullName` y `municipality` van a `user_metadata` para que
  /// [ProfileRepository.bootstrapAfterSignIn] los use al crear el perfil
  /// en el backend tras la confirmación del correo.
  ///
  /// Lanza [NetworkException] si no hay conexión y [AuthException] de Supabase
  /// si las credenciales son inválidas.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required Municipality municipality,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'municipality': municipality.name,
        },
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw const NetworkException();
    }
  }

  /// Inicia sesión con email y contraseña.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw const NetworkException();
    }
  }

  /// Cierra la sesión localmente (invalida el token en Supabase).
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignoramos errores de red al salir; la sesión local ya se elimina.
    }
  }

  /// Envía un correo de restablecimiento de contraseña.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw const NetworkException();
    }
  }

  /// Stream de cambios de sesión (signin, signout, token refresh, etc.).
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Sesión actual (puede ser null si no está autenticado).
  Session? get currentSession => _client.auth.currentSession;
}
