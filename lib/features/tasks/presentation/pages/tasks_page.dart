import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_column.dart';
import '../widgets/task_edit_sheet.dart';
import '../widgets/scan_whiteboard_sheet.dart';
import '../widgets/bucket_management_sheet.dart';
import 'tasks_calendar_page.dart';
import 'tasks_timeline_page.dart';

class TasksPage extends ConsumerStatefulWidget {
  final String? initialBucketFilter;

  const TasksPage({super.key, this.initialBucketFilter});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showCompleted = false;

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
        isReadOnly: task.isDone,
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
    final isDone = !task.isDone;
    final updatedTask = task.copyWith(
      isDone: isDone,
      completedAt: isDone ? DateTime.now() : null,
    );
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
  }

  void _onTaskDropped(Task task, String newBucket) {
    if (task.bucket != newBucket) {
      final updatedTask = task.copyWith(bucket: newBucket);
      ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    }
  }

  void _onArchiveDrop(Task task) {
    final updatedTask = task.copyWith(
      isDone: true,
      completedAt: DateTime.now(),
    );
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tasca "${task.title}" completada! ✅')),
    );
  }

  void _openBucketManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const BucketManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final bucketsAsync = ref.watch(bucketsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pissarra de Tasques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.blue),
            tooltip: 'Històric de Reformes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TasksTimelinePage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _showCompleted
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            tooltip: _showCompleted
                ? 'Amagar tasques completades'
                : 'Mostrar tasques completades',
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Gestionar Columnes',
            onPressed: _openBucketManagement,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendari de Tasques',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TasksCalendarPage()),
              );
            },
          ),
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
        data: (tasks) => bucketsAsync.when(
          data: (allBuckets) {
            // Filter out archived buckets
            final activeBuckets = allBuckets
                .where((b) => !b.isArchived)
                .where(
                  (b) =>
                      widget.initialBucketFilter == null ||
                      b.name == widget.initialBucketFilter,
                )
                .toList();

            return Column(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      itemCount: activeBuckets.length,
                      itemBuilder: (context, index) {
                        final bucket = activeBuckets[index];
                        final bucketTasks =
                            tasks
                                .where((t) => t.bucket == bucket.name)
                                .where((t) => _showCompleted || !t.isDone)
                                .toList()
                              ..sort((a, b) => a.order.compareTo(b.order));

                        return TaskColumn(
                          title: bucket.name,
                          tasks: bucketTasks,
                          onToggleTask: (id) {
                            try {
                              final task = tasks.firstWhere((t) => t.id == id);
                              _toggleTask(task);
                            } catch (e) {
                              // Task might be gone
                            }
                          },
                          onTaskDropped: (task) =>
                              _onTaskDropped(task, bucket.name),
                          onReorder: (oldIndex, newIndex) {
                            // Update order of tasks in this bucket
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = bucketTasks.removeAt(oldIndex);
                            bucketTasks.insert(newIndex, item);

                            // Initial simple implementation: update all tasks in bucket with new indices
                            // A more robust way would be using a dedicated usecase/repository method to batch update
                            for (int i = 0; i < bucketTasks.length; i++) {
                              if (bucketTasks[i].order != i) {
                                final updated = bucketTasks[i].copyWith(
                                  order: i,
                                );
                                ref
                                    .read(tasksRepositoryProvider)
                                    .updateTask(updated);
                              }
                            }
                          },
                          onAddTask: () => _createTask(bucket.name),
                          onEditTask: _editTask,
                          onDeleteTask: _deleteTask,
                          onArchiveTask: _onArchiveDrop,
                        );
                      },
                    ),
                  ),
                ),
                DragTarget<Task>(
                  onAcceptWithDetails: (details) =>
                      _onArchiveDrop(details.data),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return Container(
                      height: 80,
                      color: isHovering
                          ? Colors.green.withValues(alpha: 0.2)
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
                                  : Colors.grey.withValues(alpha: 0.5),
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
                                    : Colors.grey.withValues(alpha: 0.5),
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error buckets: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error tasks: $err')),
      ),
    );
  }
}
