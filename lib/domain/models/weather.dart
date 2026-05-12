import 'package:flutter/foundation.dart';

@immutable
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.fetchedAt,
    this.source = 'Open-Meteo',
  });

  final double temperature;
  final double humidity;
  final DateTime fetchedAt;
  final String source;

  String get temperatureLabel => '${temperature.toStringAsFixed(1)}°C';
  String get humidityLabel => '${humidity.toStringAsFixed(0)}%';
}
