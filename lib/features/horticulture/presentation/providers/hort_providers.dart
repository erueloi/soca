import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/hort_repository.dart';
import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/planta_hort.dart';

/// Stream provider per a tots els espais d'horts de la finca actual.
final espaisStreamProvider = StreamProvider<List<EspaiHort>>((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getEspaisStream();
});

/// Stream provider per a totes les plantes d'hort de la finca actual.
final plantsStreamProvider = StreamProvider<List<PlantaHort>>((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getPlantsStream();
});
