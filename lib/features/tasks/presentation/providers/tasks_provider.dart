import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../data/repositories/tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository();
});

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final repository = ref.watch(tasksRepositoryProvider);
  return repository.getTasksStream();
});
