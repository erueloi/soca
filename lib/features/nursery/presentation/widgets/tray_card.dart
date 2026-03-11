import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/nursery_models.dart';
import '../../presentation/providers/nursery_provider.dart';
import 'tray_details_sheet.dart';

/// A single card representing a [SeedTray] inside a Kanban column.
/// Tappable to open the detail sheet. Has a popup menu for status
/// changes, archiving and deletion.
class TrayCard extends ConsumerWidget {
  final SeedTray tray;

  const TrayCard({super.key, required this.tray});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final daysSincePlanting = DateTime.now().difference(tray.plantedAt).inDays;

    // Active statuses the tray can move to (excluding current and archived)
    final moveOptions = TrayStatus.values
        .where((s) => s != tray.status && s != TrayStatus.archived)
        .toList();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Main content ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tray.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildAgronomicInfo(context, daysSincePlanting),
                    // --- Item summaries ---
                    if (tray.items.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...tray.items.take(3).map((item) {
                        final name = item.speciesName.isNotEmpty
                            ? item.speciesName
                            : item.speciesId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${item.quantity}x $name',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      if (tray.items.length > 3)
                        Text(
                          '+${tray.items.length - 3} més…',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                    if (tray.expectedTransplantDate != null) ...[
                      const SizedBox(height: 4),
                      _buildTransplantChip(context),
                    ],
                  ],
                ),
              ),
              // --- Popup menu ---
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  // Move options
                  ...moveOptions.map(
                    (status) => PopupMenuItem<String>(
                      value: 'move_${status.name}',
                      child: Row(
                        children: [
                          Icon(
                            _iconForStatus(status),
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text('Moure a ${status.label}'),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Editar Safata'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Arxivar',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🗑️ Eliminar Safata',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleMenuAction(context, ref, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) {
    final notifier = ref.read(nurseryActionsProvider.notifier);

    if (value == 'archive') {
      notifier.archiveTray(tray.id);
    } else if (value == 'delete') {
      _confirmDelete(context, ref);
    } else if (value == 'edit') {
      _showEditTrayDialog(context, ref);
    } else if (value.startsWith('move_')) {
      final statusName = value.replaceFirst('move_', '');
      final newStatus = TrayStatus.values.firstWhere(
        (s) => s.name == statusName,
      );
      notifier.changeTrayStatus(tray.id, newStatus);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Safata?'),
        content: Text(
          'S\'eliminarà permanentment la safata "${tray.name}". '
          'Aquesta acció no es pot desfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel·lar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(nurseryActionsProvider.notifier).deleteTray(tray.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showEditTrayDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: tray.name);
    DateTime selectedDate = tray.plantedAt;
    final notifier = ref.read(nurseryActionsProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Safata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom de la safata',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('ca', 'ES'),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data de sembra',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy', 'ca_ES').format(selectedDate),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel·lar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                notifier.updateTray(tray.id, {
                  'name': name,
                  'plantedAt': Timestamp.fromDate(selectedDate),
                });
                Navigator.pop(ctx);
              },
              child: const Text('Desar'),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TrayDetailsSheet(trayId: tray.id),
    );
  }

  Widget _buildAgronomicInfo(BuildContext context, int daysSincePlanting) {
    final theme = Theme.of(context);

    if (tray.items.isEmpty) {
      return Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text('$daysSincePlanting dies', style: theme.textTheme.bodySmall),
        ],
      );
    }

    final estGerm = tray.estimatedGerminationDays;
    final estTransplant = tray.estimatedTransplantDays;

    switch (tray.status) {
      case TrayStatus.germination:
        final isOverdue = daysSincePlanting >= estGerm;
        return Row(
          children: [
            Icon(
              isOverdue ? Icons.notifications_active : Icons.hourglass_empty,
              size: 14,
              color: isOverdue ? Colors.orange : theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              'Dia $daysSincePlanting de ~$estGerm (Est.)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOverdue ? Colors.orange : null,
                fontWeight: isOverdue ? FontWeight.bold : null,
              ),
            ),
            if (isOverdue) ...[
              const SizedBox(width: 4),
              const Icon(Icons.eco, size: 14, color: Colors.orange),
            ],
          ],
        );

      case TrayStatus.growing:
      case TrayStatus.hardening:
        final isNearTransplant = (estTransplant - daysSincePlanting) <= 7;
        final isOverdue = daysSincePlanting >= estTransplant;

        Color? textColor;
        IconData icon = Icons.wb_sunny_outlined;

        if (isOverdue) {
          textColor = theme.colorScheme.error;
          icon = Icons.warning_amber_rounded;
        } else if (isNearTransplant) {
          textColor = Colors.orange;
          icon = Icons.notifications_active;
        }

        return Row(
          children: [
            Icon(icon, size: 14, color: textColor ?? theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              'Dia $daysSincePlanting de ~$estTransplant per trasplan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: textColor != null ? FontWeight.bold : null,
              ),
            ),
          ],
        );

      case TrayStatus.ready:
        return Row(
          children: [
            Icon(Icons.rocket_launch,
                size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'A punt per trasplantar!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case TrayStatus.archived:
        return Row(
          children: [
            Icon(Icons.archive_outlined,
                size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text('Arxivada', style: theme.textTheme.bodySmall),
          ],
        );
    }
  }

  Widget _buildTransplantChip(BuildContext context) {
    final theme = Theme.of(context);
    final daysLeft =
        tray.expectedTransplantDate!.difference(DateTime.now()).inDays;
    final isOverdue = daysLeft < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverdue
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOverdue
            ? '⚠️ Trasplant fa ${daysLeft.abs()} d'
            : '🎯 Trasplant en $daysLeft d',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isOverdue
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  IconData _iconForStatus(TrayStatus status) {
    switch (status) {
      case TrayStatus.germination:
        return Icons.dark_mode_outlined;
      case TrayStatus.growing:
        return Icons.wb_sunny_outlined;
      case TrayStatus.hardening:
        return Icons.air;
      case TrayStatus.ready:
        return Icons.rocket_launch_outlined;
      case TrayStatus.archived:
        return Icons.archive_outlined;
    }
  }
}
