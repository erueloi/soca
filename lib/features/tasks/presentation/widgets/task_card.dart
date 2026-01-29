import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/task.dart';
import '../../../directory/presentation/providers/directory_provider.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final VoidCallback onToggle;
  final Function(Task task)? onEdit;
  final Function(Task task)? onDelete;
  final Function(Task task)? onArchive;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task.isDone) {
      return GestureDetector(
        onTap: () => onEdit?.call(task),
        child: _buildCardContent(context, ref),
      );
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Archive logic
          return true;
        } else {
          // Delete logic
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Esborrar tasca?'),
                content: const Text('Segur que vols esborrar aquesta tasca?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel·lar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Esborrar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onArchive?.call(task);
        } else {
          onDelete?.call(task);
        }
      },
      child: GestureDetector(
        onTap: () => onEdit?.call(task),
        child: _buildCardContent(context, ref),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8.0),
      color: task.isDone
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isDone
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        width: 2,
                      ),
                      color: task.isDone
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                    ),
                    child: task.isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: task.isDone ? Colors.grey : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (task.totalBudget > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${task.totalBudget.toStringAsFixed(2)}€',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Data: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (task.resolution != null && task.resolution!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
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
            ],
            if (task.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: task.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: item.isDone ? Colors.grey : Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: item.description,
                                        style: TextStyle(
                                          decoration: item.isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: item.isDone
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (item.quantity != 1.0)
                                        TextSpan(
                                          text: ' (x${item.quantity})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      if (item.cost > 0)
                                        TextSpan(
                                          text:
                                              ' - ${(item.cost * item.quantity).toStringAsFixed(2)}€',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                    ],
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (task.contactIds.isNotEmpty)
              ref
                  .watch(contactsStreamProvider)
                  .when(
                    data: (allContacts) {
                      final assigned = allContacts
                          .where((c) => task.contactIds.contains(c.id))
                          .toList();
                      if (assigned.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: assigned.map((contact) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              contact.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            Text(
                                              contact.role,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () => _launchUrl(
                                                    'tel:${contact.phone}',
                                                  ),
                                                  icon: const Icon(Icons.call),
                                                  label: const Text('Trucar'),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _launchUrl(
                                                    'https://wa.me/34${contact.phone.replaceAll(RegExp(r'[^\d]'), '')}',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.message,
                                                  ),
                                                  label: const Text('WhatsApp'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Tooltip(
                                    message:
                                        '${contact.name} (${contact.role})',
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        contact.name.isNotEmpty
                                            ? contact.name.substring(0, 1)
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
            if (task.linkedResourceIds.isNotEmpty)
              ref
                  .watch(resourcesStreamProvider)
                  .when(
                    data: (allResources) {
                      final assigned = allResources
                          .where((r) => task.linkedResourceIds.contains(r.id))
                          .toList();
                      if (assigned.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          if (task.contactIds.isEmpty) const Divider(height: 1),
                          // If contacts were present, they likely added a divider.
                          // If not, we might need one.
                          // But wait, if contacts ARE present, the divider is inside their block.
                          // If contacts are NOT present (filtered out or empty list), we might want a separator here?
                          // Let's just add a small space for now, or a Divider if it's the first 'footer' item.
                          // To be safe and consistent, let's just add a small spacing.
                          // If contacts are above, we have spacing.
                          if (task.contactIds.isEmpty)
                            const SizedBox(height: 8),

                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: assigned.map((resource) {
                              return ActionChip(
                                avatar: Icon(
                                  _getResourceIcon(resource.typeId),
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                label: Text(
                                  resource.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.05),
                                side: BorderSide.none,
                                padding: const EdgeInsets.all(2),
                                onPressed: () => _launchUrl(resource.url),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
            if (task.phase.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.phase,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getResourceIcon(String typeId) {
    switch (typeId.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'excel':
      case 'spreadsheet':
      case 'full de càlcul':
      case 'full de calcul':
        return Icons.table_chart;
      case 'image':
      case 'imatge':
        return Icons.image;
      case 'link':
      case 'enllaç':
      default:
        return Icons.link;
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
