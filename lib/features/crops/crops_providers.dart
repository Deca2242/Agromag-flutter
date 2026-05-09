import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_crops.dart';
import '../../domain/models/crop.dart';

/// Lista de cultivos del usuario actual.
///
/// En la fase 2 se reemplaza por un `StreamProvider` que escuche SQLite y/o
/// Supabase Realtime sin tocar las vistas.
final cropsProvider = Provider<List<Crop>>((ref) => kMockCrops);

final cropByIdProvider = Provider.family<Crop?, String>((ref, id) {
  final crops = ref.watch(cropsProvider);
  for (final crop in crops) {
    if (crop.id == id) return crop;
  }
  return null;
});
