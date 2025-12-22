import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import 'task_card.dart';

class TaskColumn extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final Function(String taskId) onToggleTask;
  final Function(Task task)? onTaskDropped;
  final VoidCallback? onAddTask;
  final Function(Task task)? onEditTask;
  final Function(Task task)? onDeleteTask;
  final Function(Task task)? onArchiveTask;

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
  });

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tasks.length.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: tasks.map((task) {
                    return TaskCard(
                      task: task,
                      onToggle: () => onToggleTask(task.id),
                      onEdit: onEditTask,
                      onDelete: onDeleteTask,
                      onArchive: onArchiveTask,
                    );
                  }).toList(),
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
}
