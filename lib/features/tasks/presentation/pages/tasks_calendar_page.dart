import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/tasks_provider.dart';
import '../../domain/entities/task.dart';
import '../widgets/task_edit_sheet.dart';

class TasksCalendarPage extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const TasksCalendarPage({super.key, this.initialDate});

  @override
  ConsumerState<TasksCalendarPage> createState() => _TasksCalendarPageState();
}

class _TasksCalendarPageState extends ConsumerState<TasksCalendarPage> {
  late DateTime _focusedDay;
  late DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // Only tasks with dueDate
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendari de Tasques'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _focusedDay = DateTime.now();
                      _selectedDay = DateTime.now();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 6.0,
                    ),
                    child: Text(
                      'Avui',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final tasksWithDate = tasks.where((t) => t.dueDate != null).toList();

          return Column(
            children: [
              TableCalendar<Task>(
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                locale: 'ca_ES',
                startingDayOfWeek: StartingDayOfWeek.monday,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) {
                  return tasksWithDate.where((task) {
                    return isSameDay(task.dueDate, day);
                  }).toList();
                },
                calendarStyle: const CalendarStyle(
                  markersMaxCount: 4,
                  markerDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    // Check if any event is overdue (not done and date < now)
                    bool hasOverdue = events.any(
                      (t) =>
                          !t.isDone &&
                          t.dueDate!.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)),
                          ),
                    );

                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasOverdue ? Colors.red : Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: _buildTaskList(
                  _getTasksForDay(tasksWithDate, _selectedDay ?? _focusedDay),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<Task> _getTasksForDay(List<Task> tasks, DateTime day) {
    return tasks.where((task) => isSameDay(task.dueDate, day)).toList();
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'Cap tasca per aquest dia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isOverdue =
            !task.isDone &&
            task.dueDate!.isBefore(
              DateTime.now().subtract(const Duration(days: 1)),
            );

        return Card(
          color: isOverdue ? Colors.red.shade50 : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: task.isDone,
              onChanged: (val) {
                // Quick toggle status
                final updated = task.copyWith(isDone: val ?? false);
                ref.read(tasksRepositoryProvider).updateTask(updated);
              },
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                color: isOverdue && !task.isDone ? Colors.red : null,
                fontWeight: isOverdue && !task.isDone ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text(task.phase.isEmpty ? 'Sense fase' : task.phase),
            trailing: isOverdue
                ? const Icon(Icons.warning, color: Colors.red)
                : null,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => TaskEditSheet(
                  task: task,
                  initialBucket: task.bucket, // Use task's bucket
                  isReadOnly: task.isDone,
                  onSave: (updatedTask) {
                    ref.read(tasksRepositoryProvider).updateTask(updatedTask);
                  },
                  onDelete: () {
                    ref.read(tasksRepositoryProvider).deleteTask(task.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tasca "${task.title}" eliminada🗑️'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
