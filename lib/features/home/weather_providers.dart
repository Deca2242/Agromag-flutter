import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/weather_repository.dart';
import '../../domain/models/weather.dart';
import '../auth/providers/auth_providers.dart';

final weatherRepositoryProvider = Provider((ref) => WeatherRepository());

final weatherDataProvider = FutureProvider.family<WeatherData, ({double lat, double lon})>((ref, pos) async {
  final repo = ref.watch(weatherRepositoryProvider);
  return repo.getWeatherData(pos.lat, pos.lon);
});

// Provider para la ubicación del perfil
final currentLocationWeatherProvider = FutureProvider<WeatherData>((ref) async {
  final repo = ref.watch(weatherRepositoryProvider);
  final profileAsync = ref.watch(currentProfileProvider);
  
  // Usar coordenadas por defecto si el perfil aún no carga
  double lat = 11.2408; // Santa Marta por defecto
  double lon = -74.1992;
  
  if (profileAsync is AsyncData && profileAsync.value != null) {
    lat = profileAsync.value!.municipality.latitude;
    lon = profileAsync.value!.municipality.longitude;
  }
  
  return repo.getWeatherData(lat, lon);
});
