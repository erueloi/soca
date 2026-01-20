import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../widgets/task_card.dart';
import '../pages/cost_dashboard_page.dart';

class TaskColumn extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final Function(String taskId) onToggleTask;
  final Function(Task task)? onTaskDropped;
  final VoidCallback? onAddTask;
  final Function(Task task)? onEditTask;
  final Function(Task task)? onDeleteTask;
  final Function(Task task)? onArchiveTask;
  final Function(int oldIndex, int newIndex)? onReorder;
  final List<Task>? allTasks;

  const TaskColumn({
    super.key,
    required this.title,
    required this.tasks,
    required this.onToggleTask,
    this.onTaskDropped,
    this.onAddTask,
    this.onEditTask,
    this.onDeleteTask,
    this.onArchiveTask,
    this.onReorder,
    this.allTasks,
  });

  @override
  Widget build(BuildContext context) {
    final summaryTasks = allTasks ?? tasks;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.bucket != title,
      onAcceptWithDetails: (details) {
        onTaskDropped?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 16.0),
          decoration: BoxDecoration(
            color: isHovering
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withValues(alpha: 0.2),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tasks.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Financial Summary
                          Builder(
                            builder: (context) {
                              final totalBudget = summaryTasks.fold<double>(
                                0,
                                (sum, t) => sum + t.totalBudget,
                              );
                              final totalSpent = summaryTasks.fold<double>(
                                0,
                                (sum, t) => sum + t.totalSpent,
                              );
                              final saldo = totalBudget - totalSpent;

                              if (totalBudget == 0 && totalSpent == 0) {
                                return const SizedBox.shrink();
                              }

                              return InkWell(
                                onTap: () =>
                                    _showCostBreakdown(context, summaryTasks),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Pressupost: ${totalBudget.toStringAsFixed(0)}€',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        ' | ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      Text(
                                        'Gastat: ${totalSpent.toStringAsFixed(0)}€',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        ' | ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      Text(
                                        'Saldo: ${saldo.toStringAsFixed(0)}€',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: saldo < 0
                                              ? Colors.red
                                              : Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.info_outline,
                                        size: 12,
                                        color: Colors.blue.shade800,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.all(8),
                  itemCount: tasks.length,
                  onReorder: (oldIndex, newIndex) {
                    onReorder?.call(oldIndex, newIndex);
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Container(
                      key: ValueKey(task.id),
                      child: Stack(
                        children: [
                          TaskCard(
                            task: task,
                            onToggle: () => onToggleTask(task.id),
                            onEdit: onEditTask,
                            onDelete: onDeleteTask,
                            onArchive: onArchiveTask,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: onReorder != null
                                ? ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      width: 30,
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.drag_indicator,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: 30),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (onAddTask != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onAddTask,
                      icon: const Icon(Icons.add),
                      label: const Text('Afegir Tasca'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.centerLeft,
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCostBreakdown(
    BuildContext context,
    List<Task> summaryTasks,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CostDashboardPage(columnName: title, tasks: summaryTasks),
      ),
    );
  }
}
