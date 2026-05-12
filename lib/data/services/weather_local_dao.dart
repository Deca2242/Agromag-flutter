import 'package:sqflite/sqflite.dart';

import '../../domain/models/municipality.dart';
import '../../domain/models/weather.dart';
import 'local_db.dart';

/// CRUD de la tabla `weather_cache` en SQLite.
class WeatherLocalDao {
  const WeatherLocalDao();

  Future<void> upsert(Municipality municipality, CurrentWeather weather) async {
    await LocalDb.instance.db.insert(
      'weather_cache',
      {
        'municipality': municipality.name,
        'temperature': weather.temperature,
        'humidity': weather.humidity,
        'fetched_at': weather.fetchedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CurrentWeather?> find(Municipality municipality) async {
    final rows = await LocalDb.instance.db.query(
      'weather_cache',
      where: 'municipality = ?',
      whereArgs: [municipality.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return CurrentWeather(
      temperature: (row['temperature'] as num).toDouble(),
      humidity: (row['humidity'] as num).toDouble(),
      fetchedAt: DateTime.parse(row['fetched_at'] as String),
      source: 'cache',
    );
  }

  Future<void> clear() async {
    await LocalDb.instance.db.delete('weather_cache');
  }
}
