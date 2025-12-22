import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_column.dart';
import '../widgets/task_edit_sheet.dart';
import '../widgets/scan_whiteboard_sheet.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final ScrollController _scrollController =
      ScrollController(); // Added controller

  final List<String> buckets = [
    'Valla exterior',
    'Sala d\'estar',
    'Aigua',
    'Arquitectura/Planols',
    'Documentació',
    'Reforestació',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _createTask(String bucket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskEditSheet(
        initialBucket: bucket,
        onSave: (task) {
          // Saving is handled inside TaskEditSheet now for new tasks (including upload)
          // But wait, TaskEditSheet was designed to call onSave with the Text object.
          // Let's keep it simple: TaskEditSheet handles the async upload and then calls onSave with the final task?
          // Or does it handle everything?
          // The previous request said: "Program saveTaskToFirestore inside the dialog".
          // So onSave might just be for UI update or redundant if we listen to Stream.
          // If we listen to stream, we don't need manual UI update.
          // However, for clean arch, maybe we pass the repository action?
          // Let's stick to the pattern:
          // The Sheet will handle the logic of creating the task and calling repo.
          // But to decoupling, we can pass a callback that calls the repo.
          ref.read(tasksRepositoryProvider).addTask(task);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tasca afegida al Molí! 🌾')),
          );
        },
      ),
    );
  }

  void _editTask(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskEditSheet(
        task: task,
        initialBucket: task.bucket,
        onSave: (updatedTask) {
          ref.read(tasksRepositoryProvider).updateTask(updatedTask);
        },
        onDelete: () => _deleteTask(task),
      ),
    );
  }

  void _deleteTask(Task task) {
    ref.read(tasksRepositoryProvider).deleteTask(task.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tasca "${task.title}" eliminada🗑️')),
    );
  }

  void _toggleTask(Task task) {
    final updatedTask = task.copyWith(isDone: !task.isDone);
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
  }

  void _onTaskDropped(Task task, String newBucket) {
    if (task.bucket != newBucket) {
      final updatedTask = task.copyWith(bucket: newBucket);
      ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    }
  }

  void _onArchiveDrop(Task task) {
    final updatedTask = task.copyWith(isDone: true);
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tasca "${task.title}" completada! ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pissarra de Tasques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Sincronització Analògica (OCR)',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => const ScanWhiteboardSheet(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController, // Check #1
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController, // Check #2
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  itemCount: buckets.length,
                  itemBuilder: (context, index) {
                    final bucket = buckets[index];
                    final bucketTasks = tasks
                        .where((t) => t.bucket == bucket)
                        .toList();
                    return TaskColumn(
                      title: bucket,
                      tasks: bucketTasks,
                      onToggleTask: (id) {
                        // Find task safely
                        try {
                          final task = tasks.firstWhere((t) => t.id == id);
                          _toggleTask(task);
                        } catch (e) {
                          // Task might be gone
                        }
                      },
                      onTaskDropped: (task) => _onTaskDropped(task, bucket),
                      onAddTask: () => _createTask(bucket),
                      onEditTask: _editTask,
                      onDeleteTask: _deleteTask,
                      onArchiveTask: _onArchiveDrop,
                    );
                  },
                ),
              ),
            ),
            DragTarget<Task>(
              onAcceptWithDetails: (details) => _onArchiveDrop(details.data),
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Container(
                  height: 80,
                  color: isHovering
                      ? Colors.green.withOpacity(0.2)
                      : Colors.transparent,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isHovering
                              ? Icons.check_circle
                              : Icons.archive_outlined,
                          color: isHovering
                              ? Colors.green
                              : Colors.grey.withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHovering
                              ? 'Deixa anar per Completar!'
                              : 'Arrossega aquí per Completar Ràpidament',
                          style: TextStyle(
                            color: isHovering
                                ? Colors.green
                                : Colors.grey.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
