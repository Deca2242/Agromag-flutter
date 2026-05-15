import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/weather_repository.dart';
import '../../data/services/open_meteo_api.dart';
import '../../data/services/weather_local_dao.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/weather.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(api: OpenMeteoApi(), dao: const WeatherLocalDao());
});

/// Pronóstico completo (actual + horario + 7 días). Misma caché TTL + SQLite.
final weatherDataProvider = FutureProvider.family<WeatherData, Municipality>((
  ref,
  municipality,
) {
  return ref.read(weatherRepositoryProvider).getWeatherData(municipality);
});

/// Solicita el clima actual para el municipio dado.
/// Fallback a caché SQLite si no hay red.
final currentWeatherProvider =
    FutureProvider.family<CurrentWeather, Municipality>((ref, municipality) {
      return ref.read(weatherRepositoryProvider).getWeather(municipality);
    });
