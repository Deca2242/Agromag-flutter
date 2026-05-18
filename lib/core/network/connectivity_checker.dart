import 'package:dio/dio.dart';

import '../config/env.dart';

// Verifica conectividad real con el servidor mediante GET /api/health.
// connectivity_plus solo detecta que hay una interfaz de red disponible;
// este checker confirma que el backend Spring es alcanzable.
// El resultado se cachea 30 segundos para evitar pings excesivos.
class ConnectivityChecker {
  ConnectivityChecker._();

  static final ConnectivityChecker instance = ConnectivityChecker._();

  static const _cacheDuration = Duration(seconds: 30);
  static const _timeout = Duration(seconds: 3);

  DateTime? _lastCheck;
  bool _lastResult = false;

  /// Verifica que el backend responde con HTTP 200.
  /// [forceCheck] ignora el cache y siempre hace el ping.
  Future<bool> isReachable({bool forceCheck = false}) async {
    final now = DateTime.now();
    if (!forceCheck &&
        _lastCheck != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _lastResult;
    }

    _lastCheck = now;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );
      final response = await dio.get<void>('/api/health');
      _lastResult = response.statusCode == 200;
    } catch (_) {
      _lastResult = false;
    }
    return _lastResult;
  }

  /// Invalida el cache para forzar re-verificación en la próxima llamada.
  void invalidate() {
    _lastCheck = null;
  }
}
