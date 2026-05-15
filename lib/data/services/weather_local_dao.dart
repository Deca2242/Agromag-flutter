import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/municipality.dart';
import '../../domain/models/weather.dart';
import 'local_db.dart';

/// CRUD de la tabla `weather_cache` en SQLite.
class WeatherLocalDao {
  const WeatherLocalDao();

  Future<void> upsert(Municipality municipality, CurrentWeather weather) async {
    await upsertWeatherData(
      municipality,
      WeatherData(current: weather, hourly: const [], daily: const []),
    );
  }

  Future<void> upsertWeatherData(
    Municipality municipality,
    WeatherData data,
  ) async {
    final w = data.current;
    await LocalDb.instance.db.insert('weather_cache', {
      'municipality': municipality.name,
      'temperature': w.temperature,
      'humidity': w.humidity,
      'fetched_at': w.fetchedAt.toIso8601String(),
      'forecast_json': jsonEncode(data.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CurrentWeather?> find(Municipality municipality) async {
    final data = await findWeatherData(municipality);
    return data?.current;
  }

  /// Devuelve pronóstico completo si hay JSON; si no, un mínimo desde columnas legacy.
  Future<WeatherData?> findWeatherData(Municipality municipality) async {
    final rows = await LocalDb.instance.db.query(
      'weather_cache',
      where: 'municipality = ?',
      whereArgs: [municipality.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final jsonRaw = row['forecast_json'] as String?;
    final decoded = WeatherData.decodeFromForecastJson(jsonRaw);
    if (decoded != null) return decoded;

    return WeatherData(
      current: CurrentWeather.fromLegacyRow(
        temperature: (row['temperature'] as num).toDouble(),
        humidity: (row['humidity'] as num).toDouble(),
        fetchedAt: DateTime.parse(row['fetched_at'] as String),
        source: 'cache',
      ),
      hourly: const [],
      daily: const [],
    );
  }

  Future<void> clear() async {
    await LocalDb.instance.db.delete('weather_cache');
  }
}
