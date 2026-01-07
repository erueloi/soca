import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';

class TasksTimelinePage extends ConsumerStatefulWidget {
  const TasksTimelinePage({super.key});

  @override
  ConsumerState<TasksTimelinePage> createState() => _TasksTimelinePageState();
}

class _TasksTimelinePageState extends ConsumerState<TasksTimelinePage> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline de Tasques')),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final entries = _buildTimelineEntries(tasks);
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hi ha historial disponible.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry is _MonthHeader) {
                      return _buildMonthHeader(entry);
                    } else if (entry is _TimelineItem) {
                      return _buildTimelineItem(entry);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cerca per nom...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _dateRange == null
                        ? 'Filtrar per dates'
                        : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  ),
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dateRange = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<dynamic> _buildTimelineEntries(List<Task> tasks) {
    final List<_TimelineItem> items = [];

    for (final task in tasks) {
      if (task.isDone && task.completedAt != null) {
        if (_matchesFilters(task.title, task.completedAt!)) {
          items.add(
            _TimelineItem(
              title: task.title,
              completedAt: task.completedAt!,
              cost: task.totalSpent,
              isSubtask: false,
            ),
          );
        }
      }

      for (final item in task.items) {
        if (item.isDone && item.completedAt != null) {
          if (_matchesFilters(item.description, item.completedAt!)) {
            items.add(
              _TimelineItem(
                title: item.description,
                completedAt: item.completedAt!,
                cost: item.cost * item.quantity,
                isSubtask: true,
                parentTaskTitle: task.title,
              ),
            );
          }
        }
      }
    }

    items.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final List<dynamic> result = [];
    String? currentMonth;

    for (final item in items) {
      final monthKey = '${item.completedAt.year}-${item.completedAt.month}';
      if (currentMonth != monthKey) {
        currentMonth = monthKey;
        result.add(_MonthHeader(item.completedAt));
      }
      result.add(item);
    }

    return result;
  }

  bool _matchesFilters(String text, DateTime date) {
    final searchText = _searchController.text.toLowerCase();
    if (searchText.isNotEmpty && !text.toLowerCase().contains(searchText)) {
      return false;
    }
    if (_dateRange != null) {
      if (date.isBefore(_dateRange!.start) ||
          date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
        return false;
      }
    }
    return true;
  }

  Widget _buildMonthHeader(_MonthHeader header) {
    final months = [
      'Gener',
      'Febrer',
      'Març',
      'Abril',
      'Maig',
      'Juny',
      'Juliol',
      'Agost',
      'Setembre',
      'Octubre',
      'Novembre',
      'Desembre',
    ];
    final monthName = months[header.date.month - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$monthName ${header.date.year}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 16)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isSubtask ? Colors.grey : Colors.green,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey[700],
                  ),
                ),
                if (item.isSubtask && item.parentTaskTitle != null)
                  Text(
                    'Subtasca de: ${item.parentTaskTitle}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${item.completedAt.day}/${item.completedAt.month} ${item.completedAt.hour}:${item.completedAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (item.cost > 0) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.euro, size: 14, color: Colors.orange[700]),
                      Text(
                        item.cost.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader {
  final DateTime date;
  _MonthHeader(this.date);
}

class _TimelineItem {
  final String title;
  final DateTime completedAt;
  final double cost;
  final bool isSubtask;
  final String? parentTaskTitle;

  _TimelineItem({
    required this.title,
    required this.completedAt,
    required this.cost,
    required this.isSubtask,
    this.parentTaskTitle,
  });
}
