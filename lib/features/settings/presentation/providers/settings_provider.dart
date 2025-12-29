import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/farm_config.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(FirebaseFirestore.instance);
});

final farmConfigStreamProvider = StreamProvider<FarmConfig>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getFarmConfigStream();
});
