import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/crop_local_dao.dart';
import '../../domain/models/crop.dart';

final cropLocalDaoProvider = Provider((ref) => const CropLocalDao());

class CropsNotifier extends AsyncNotifier<List<Crop>> {
  @override
  Future<List<Crop>> build() async {
    final dao = ref.watch(cropLocalDaoProvider);
    return dao.getAll();
  }

  Future<void> addCrop(Crop crop) async {
    final dao = ref.read(cropLocalDaoProvider);
    await dao.insert(crop);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => dao.getAll());
  }
}

final cropsProvider = AsyncNotifierProvider<CropsNotifier, List<Crop>>(() {
  return CropsNotifier();
});

final cropByIdProvider = Provider.family<Crop?, String>((ref, id) {
  final cropsAsync = ref.watch(cropsProvider);
  final crops = cropsAsync.value ?? [];
  for (final crop in crops) {
    if (crop.id == id) return crop;
  }
  return null;
});
