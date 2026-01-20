import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/bucket.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final configAsync = ref.watch(farmConfigStreamProvider);
  final fincaId = configAsync.value?.fincaId;
  return TasksRepository(fincaId: fincaId);
});

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final repository = ref.watch(tasksRepositoryProvider);
  return repository.getTasksStream();
});

final bucketsStreamProvider = StreamProvider<List<Bucket>>((ref) {
  final repository = ref.watch(tasksRepositoryProvider);
  return repository.getBucketsStream();
});
