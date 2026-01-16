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
  final DateTime? initialDate;

  const TasksPage({super.key, this.initialBucketFilter, this.initialDate});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

enum SortMethod { manual, dateDesc, dateAsc, createdDesc }

class _TasksPageState extends ConsumerState<TasksPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _showCompleted = false;
  bool _isSearching = false;
  SortMethod _sortMethod = SortMethod.dateAsc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // ... existing initState logic ...
    if (widget.initialDate != null) {
      // If a date is provided, navigate directly to calendar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TasksCalendarPage(initialDate: widget.initialDate),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ... (Keep existing methods: _createTask, _editTask, _deleteTask, _toggleTask, _onTaskDropped, _onArchiveDrop, _promptCompletionWithResolution, _openBucketManagement)

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

  Future<void> _toggleTask(Task task) async {
    final isDone = !task.isDone;
    DateTime? completionDate;
    String? resolution;

    if (isDone) {
      final result = await _promptCompletionWithResolution(task.title);
      if (result == null) return; // Cancelled
      completionDate = result['date'] as DateTime;
      resolution = result['resolution'] as String;
    }

    final updatedTask = task.copyWith(
      isDone: isDone,
      completedAt: isDone ? completionDate : null,
      resolution: isDone ? resolution : null,
    );
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
  }

  Future<void> _onTaskDropped(Task task, String newBucket) async {
    if (task.bucket != newBucket) {
      final updatedTask = task.copyWith(bucket: newBucket);
      ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    }
  }

  Future<void> _onArchiveDrop(Task task) async {
    final result = await _promptCompletionWithResolution(task.title);
    if (result == null) return;

    final updatedTask = task.copyWith(
      isDone: true,
      completedAt: result['date'] as DateTime,
      resolution: result['resolution'] as String,
    );
    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tasca "${task.title}" completada! ✅')),
    );
  }

  Future<Map<String, dynamic>?> _promptCompletionWithResolution(
    String taskTitle,
  ) async {
    DateTime selectedDate = DateTime.now();
    final TextEditingController resolutionController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Completar Tasca'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasca: $taskTitle',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Data de finalització:'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: now,
                      );
                      if (pickedDate != null) {
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resolutionController,
                    decoration: const InputDecoration(
                      labelText: 'Resolució / Notes',
                      hintText: 'Ex: S\'ha arreglat canviant la peça...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL·LAR'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'date': selectedDate,
                      'resolution': resolutionController.text,
                    });
                  },
                  child: const Text('COMPLETAR TASCA'),
                ),
              ],
            );
          },
        );
      },
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cercar tasques...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              )
            : const Text('Pissarra de Tasques'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Cercar',
              onPressed: () => setState(() => _isSearching = true),
            ),

          PopupMenuButton<SortMethod>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sortMethod,
            onSelected: (val) => setState(() => _sortMethod = val),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortMethod.manual,
                child: Text('Manual (Drag & Drop)'),
              ),
              const PopupMenuItem(
                value: SortMethod.dateAsc,
                child: Text('Data Límit (Ascendent)'),
              ),
              const PopupMenuItem(
                value: SortMethod.dateDesc,
                child: Text('Data Límit (Descendent)'),
              ),
              const PopupMenuItem(
                value: SortMethod.createdDesc,
                child: Text('Més recents'),
              ),
            ],
          ),

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

                        // 1. Filter by Bucket and Completion
                        var filteredTasks = tasks
                            .where((t) => t.bucket == bucket.name)
                            .where((t) => _showCompleted || !t.isDone);

                        // 2. Filter by Search
                        if (_searchQuery.isNotEmpty) {
                          filteredTasks = filteredTasks.where((t) {
                            return t.title.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                t.description.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                t.items.any(
                                  (i) => i.description.toLowerCase().contains(
                                    _searchQuery,
                                  ),
                                );
                          });
                        }

                        // 3. Sort
                        var bucketTasks = filteredTasks.toList();
                        switch (_sortMethod) {
                          case SortMethod.manual:
                            bucketTasks.sort(
                              (a, b) => a.order.compareTo(b.order),
                            );
                            break;
                          case SortMethod.dateAsc:
                            bucketTasks.sort((a, b) {
                              if (a.dueDate == null) return 1;
                              if (b.dueDate == null) return -1;
                              return a.dueDate!.compareTo(b.dueDate!);
                            });
                            break;
                          case SortMethod.dateDesc:
                            bucketTasks.sort((a, b) {
                              if (a.dueDate == null) return 1;
                              if (b.dueDate == null) return -1;
                              return b.dueDate!.compareTo(a.dueDate!);
                            });
                            break;
                          case SortMethod.createdDesc:
                            // Assuming ID is vague timestamp or we don't have created date,
                            // falling back to ID string compare as proxy (if time-based IDs) or just ID.
                            // Actually ID is time millis string in TaskEditSheet.
                            bucketTasks.sort((a, b) => b.id.compareTo(a.id));
                            break;
                        }

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
                          onReorder: _sortMethod == SortMethod.manual
                              ? (oldIndex, newIndex) {
                                  // Update order of tasks in this bucket
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = bucketTasks.removeAt(oldIndex);
                                  bucketTasks.insert(newIndex, item);

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
                                }
                              : null, // Disable reorder callback if sorted
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
