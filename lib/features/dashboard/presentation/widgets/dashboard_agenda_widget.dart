import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/tasks/domain/entities/task.dart';
import '../../../../features/tasks/presentation/providers/tasks_provider.dart';
import '../../../../features/tasks/presentation/widgets/task_edit_sheet.dart';
import '../../../../features/tasks/presentation/pages/tasks_calendar_page.dart';

class DashboardAgendaWidget extends ConsumerWidget {
  const DashboardAgendaWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, ref),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => _buildAgendaList(context, tasks),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TasksCalendarPage()),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
            tooltip: 'Afegir Tasca Ràpida',
            onPressed: () => _openTaskEdit(context, ref, null),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaList(BuildContext context, List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter: Future tasks (dueDate >= today) and Not Done
    final futureTasks = tasks.where((t) {
      if (t.isDone || t.dueDate == null) return false;
      final tDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !tDate.isBefore(today);
    }).toList();

    // Sort by date
    futureTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    if (futureTasks.isEmpty) {
      return Center(
        child: Text(
          'Cap tasca pendent',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    // Group by Day
    final groupedTasks = <DateTime, List<Task>>{};
    for (var task in futureTasks) {
      final date = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      groupedTasks.putIfAbsent(date, () => []).add(task);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: groupedTasks.length,
      itemBuilder: (context, index) {
        final date = groupedTasks.keys.elementAt(index);
        final dailyTasks = groupedTasks[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(context, date),
            ...dailyTasks.map((task) => _buildTaskCard(context, task)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dayName;
    if (date == today) {
      dayName = 'Avui';
    } else if (date == tomorrow) {
      dayName = 'Demà';
    } else {
      dayName = DateFormat('EEEE', 'ca_ES').format(date);
      // Capitalize first letter
      dayName = dayName[0].toUpperCase() + dayName.substring(1);
    }

    final dayNumber = date.day.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            dayNumber,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    return Consumer(
      builder: (context, ref, _) {
        return GestureDetector(
          onTap: () {
            _openTaskEdit(context, ref, task);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _getBucketColor(task.bucket).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: _getBucketColor(task.bucket), width: 4),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            task.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (task.totalBudget > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${task.totalBudget.toStringAsFixed(0)}€',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _getBucketColor(task.bucket),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBucketColor(String bucket) {
    switch (bucket) {
      case 'Obra':
        return Colors.blue;
      case 'Materials':
        return Colors.red;
      case 'Instal·lacions':
        return Colors.green;
      default:
        return Colors.teal; // Soca default color-ish
    }
  }

  void _openTaskEdit(BuildContext context, WidgetRef ref, Task? task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskEditSheet(
        task: task,
        initialBucket: task?.bucket ?? 'Obra',
        onSave: (savedTask) {
          if (task == null) {
            ref.read(tasksRepositoryProvider).addTask(savedTask);
          } else {
            ref.read(tasksRepositoryProvider).updateTask(savedTask);
          }
        },
        onDelete: task == null
            ? null
            : () {
                ref.read(tasksRepositoryProvider).deleteTask(task.id);
              },
      ),
    );
  }
}
