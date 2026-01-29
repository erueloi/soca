import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/tasks_provider.dart';
import '../../domain/entities/task.dart';
import '../widgets/task_edit_sheet.dart';
import '../../../directory/presentation/providers/directory_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/domain/entities/farm_config.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _toggleTask(Task task) async {
    final isDone = !task.isDone;
    DateTime? completionDate;
    String? resolution;

    if (isDone) {
      final result = await _promptCompletionWithResolution(task.title);
      if (result == null) return;
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
          child: Column(
            children: [
              ListTile(
                leading: Checkbox(
                  value: task.isDone,
                  onChanged: (val) => _toggleTask(task),
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: isOverdue && !task.isDone ? Colors.red : null,
                    fontWeight: isOverdue && !task.isDone
                        ? FontWeight.bold
                        : null,
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
                        ref
                            .read(tasksRepositoryProvider)
                            .updateTask(updatedTask);
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
              if (task.contactIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final contactsAsync = ref.watch(contactsStreamProvider);
                      return contactsAsync.when(
                        data: (contacts) {
                          final assigned = contacts
                              .where((c) => task.contactIds.contains(c.id))
                              .toList();
                          if (assigned.isEmpty) return const SizedBox.shrink();
                          return Wrap(
                            spacing: 8,
                            children: assigned.map((c) {
                              return ActionChip(
                                avatar: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name.substring(0, 1)
                                        : '?',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                label: Text(
                                  c.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                side: BorderSide(color: Colors.grey.shade300),
                                onPressed: () => _showContactActionDialog(c),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              if (task.linkedResourceIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final resourcesAsync = ref.watch(resourcesStreamProvider);
                      final configAsync = ref.watch(farmConfigStreamProvider);
                      return resourcesAsync.when(
                        data: (resources) {
                          final linked = resources
                              .where(
                                (r) => task.linkedResourceIds.contains(r.id),
                              )
                              .toList();
                          if (linked.isEmpty) return const SizedBox.shrink();
                          return Wrap(
                            spacing: 8,
                            children: linked.map((resource) {
                              final typeConfig = configAsync.maybeWhen(
                                data: (config) =>
                                    config.resourceTypes.firstWhere(
                                      (t) => t.id == resource.typeId,
                                      orElse: () => ResourceTypeConfig(
                                        id: 'other',
                                        name: 'Altre',
                                        colorHex: 'FF9E9E9E',
                                        iconCode: 0xe24d,
                                      ),
                                    ),
                                orElse: () => ResourceTypeConfig(
                                  id: 'other',
                                  name: 'Altre',
                                  colorHex: 'FF9E9E9E',
                                  iconCode: 0xe24d,
                                ),
                              );
                              final color = Color(
                                int.tryParse(typeConfig.colorHex, radix: 16) ??
                                    0xFF9E9E9E,
                              );
                              return ActionChip(
                                label: Text(
                                  resource.title,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: Icon(
                                  IconData(
                                    typeConfig.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  size: 14,
                                  color: color,
                                ),
                                backgroundColor: color.withValues(alpha: 0.1),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  final uri = Uri.tryParse(resource.url);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              if (task.resolution != null && task.resolution!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.resolution!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (task.items.isNotEmpty || task.totalBudget > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (task.items.isNotEmpty) ...[
                        const Divider(),
                        ...task.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              left: 8.0,
                              bottom: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.isDone
                                      ? Icons.check_circle_outline
                                      : Icons.circle_outlined,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      decoration: item.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                if (item.cost > 0)
                                  Text(
                                    '${(item.cost * item.quantity).toStringAsFixed(2)}€',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (task.totalBudget > 0) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Chip(
                            label: Text(
                              'Cost Total: ${task.totalBudget.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.amber.shade100,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showContactActionDialog(dynamic contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
            Text(contact.role, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri launchUri = Uri(
                      scheme: 'tel',
                      path: contact.phone,
                    );
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(launchUri);
                    }
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Trucar'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final cleanNumber = contact.phone.replaceAll(
                      RegExp(r'[^\d]'),
                      '',
                    );
                    final Uri launchUri = Uri.parse(
                      'https://wa.me/34$cleanNumber',
                    );
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(
                        launchUri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
