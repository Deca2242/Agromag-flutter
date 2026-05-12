import '../services/open_meteo_api.dart';
import '../services/weather_local_dao.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/weather.dart';

/// Obtiene clima con caché en memoria (TTL 10 min) + persistencia SQLite.
///
/// Estrategia:
///   1. Si el cache en memoria es fresco → devuelve inmediatamente.
///   2. Si no → llama a Open-Meteo y persiste en SQLite.
///   3. Si falla la red → usa el cache SQLite (puede ser de sesiones anteriores).
///   4. Si tampoco hay cache SQLite → relanza la excepción.
class WeatherRepository {
  WeatherRepository({required OpenMeteoApi api, required WeatherLocalDao dao})
      : _api = api,
        _dao = dao;

  final OpenMeteoApi _api;
  final WeatherLocalDao _dao;

  static const _cacheTtl = Duration(minutes: 10);

  final Map<Municipality, CurrentWeather> _memCache = {};

  Future<CurrentWeather> getWeather(Municipality municipality) async {
    final memo = _memCache[municipality];
    if (memo != null &&
        DateTime.now().difference(memo.fetchedAt) < _cacheTtl) {
      return memo;
    }

    try {
      final fresh = await _api.fetchWeather(municipality);
      _memCache[municipality] = fresh;
      await _dao.upsert(municipality, fresh);
      return fresh;
    } catch (e) {
      final stored = await _dao.find(municipality);
      if (stored != null) {
        _memCache[municipality] = stored;
        return stored;
      }
      rethrow;
    }
  }
}
