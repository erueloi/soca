import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/construction_repository.dart';
import '../../data/models/construction_point.dart';

// Repository Provider
final constructionRepositoryProvider = Provider<ConstructionRepository>((ref) {
  return ConstructionRepository();
});

// Floor Plans Stream
final floorPlansStreamProvider = StreamProvider<Map<String, String>>((ref) {
  final repository = ref.watch(constructionRepositoryProvider);
  return repository.getFloorPlans();
});

// Points Stream (Family by Floor ID)
final constructionPointsProvider =
    StreamProvider.family<List<ConstructionPoint>, String>((ref, floorId) {
      final repository = ref.watch(constructionRepositoryProvider);
      return repository.getPoints(floorId);
    });

// All Points Stream (For Dashboard)
final allConstructionPointsProvider = StreamProvider<List<ConstructionPoint>>((
  ref,
) {
  final repository = ref.watch(constructionRepositoryProvider);
  return repository.getAllPoints();
});

// Current Selected Point (Notifier for mutable state)
final selectedPointProvider =
    NotifierProvider<SelectedPointNotifier, ConstructionPoint?>(
      SelectedPointNotifier.new,
    );

class SelectedPointNotifier extends Notifier<ConstructionPoint?> {
  @override
  ConstructionPoint? build() => null;

  void set(ConstructionPoint? point) {
    state = point;
  }
}
