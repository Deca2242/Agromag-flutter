import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza el acceso a las variables de entorno del archivo `.env`.
///
/// Lanza [StateError] si alguna variable requerida está ausente o vacía,
/// lo que hace que el fallo sea visible desde el arranque.
class Env {
  const Env._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get apiBaseUrl => _require('API_BASE_URL');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Variable de entorno requerida no configurada: $key\n'
        'Copia .env.example a .env y rellena los valores.',
      );
    }
    return value;
  }
}
