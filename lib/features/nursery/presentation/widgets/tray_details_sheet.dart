import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/nursery_models.dart';
import '../../presentation/providers/nursery_provider.dart';
import 'add_seed_dialog.dart';

/// Bottom sheet showing the full details of a [SeedTray], including its
/// items list and actions to add, edit and delete seeds.
/// Listens to [nurseryTraysStreamProvider] so it refreshes live.
class TrayDetailsSheet extends ConsumerWidget {
  final String trayId;

  const TrayDetailsSheet({super.key, required this.trayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy', 'ca_ES');
    final traysAsync = ref.watch(nurseryTraysStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: traysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (trays) {
              final tray = trays.where((t) => t.id == trayId).firstOrNull;
              if (tray == null) {
                return const Center(
                  child: Text('Safata no trobada o eliminada.'),
                );
              }

              final daysSincePlanting =
                  DateTime.now().difference(tray.plantedAt).inDays;

              return Column(
                children: [
                  // --- Handle ---
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tray.name,
                                style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tray.status.label,
                                style:
                                    theme.textTheme.labelMedium?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16,
                                color: theme.colorScheme.outline),
                            const SizedBox(width: 6),
                            Text(
                              'Sembrada: ${dateFormat.format(tray.plantedAt)} '
                              '($daysSincePlanting dies)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        if (tray.expectedTransplantDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event,
                                  size: 16,
                                  color: theme.colorScheme.outline),
                              const SizedBox(width: 6),
                              Text(
                                'Trasplant previst: '
                                '${dateFormat.format(tray.expectedTransplantDate!)}',
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  // --- Items List ---
                  Expanded(
                    child: tray.items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.eco_outlined,
                                    size: 48,
                                    color:
                                        theme.colorScheme.outlineVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'La safata està buida.\n'
                                    'Afegeix llavors per començar.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: tray.items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = tray.items[index];
                              return Dismissible(
                                key: ValueKey(
                                    '${item.speciesId}_${index}_${item.quantity}'),
                                direction:
                                    DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(
                                      right: 20),
                                  color: theme.colorScheme.errorContainer,
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: theme
                                        .colorScheme.onErrorContainer,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title:
                                          const Text('Eliminar llavor?'),
                                      content: Text(
                                        'S\'eliminarà "${item.speciesName.isNotEmpty ? item.speciesName : item.speciesId}" '
                                        '(${item.quantity} unitats) de la safata.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child:
                                              const Text('Cancel·lar'),
                                        ),
                                        FilledButton(
                                          style:
                                              FilledButton.styleFrom(
                                            backgroundColor: theme
                                                .colorScheme.error,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child:
                                              const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (_) {
                                  ref
                                      .read(nurseryActionsProvider
                                          .notifier)
                                      .removeTrayItem(
                                        tray.id,
                                        tray.items,
                                        index,
                                      );
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: theme
                                        .colorScheme.primaryContainer,
                                    child: Text(
                                      '${item.quantity}',
                                      style: TextStyle(
                                        color: theme.colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.speciesName.isNotEmpty
                                        ? item.speciesName
                                        : item.speciesId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: item.germinatedCount != null
                                      ? Text(
                                          '${item.germinatedCount} germinades')
                                      : null,
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: theme.colorScheme.outline,
                                    ),
                                    tooltip: 'Editar quantitat',
                                    onPressed: () =>
                                        _showEditItemDialog(
                                      context,
                                      ref,
                                      tray,
                                      index,
                                      item,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // --- Add Seeds Button ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: FilledButton.icon(
                      onPressed: () => _showAddSeedDialog(context, trayId),
                      icon: const Icon(Icons.add),
                      label: const Text('🌱 Afegeix Llavors'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showAddSeedDialog(BuildContext context, String trayId) {
    showDialog(
      context: context,
      builder: (_) => AddSeedDialog(trayId: trayId),
    );
  }

  void _showEditItemDialog(
    BuildContext context,
    WidgetRef ref,
    SeedTray tray,
    int index,
    TrayItem item,
  ) {
    final theme = Theme.of(context);
    final qtyController =
        TextEditingController(text: '${item.quantity}');
    final germController = TextEditingController(
        text: item.germinatedCount != null ? '${item.germinatedCount}' : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Editar: ${item.speciesName.isNotEmpty ? item.speciesName : item.speciesId}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: 'Quantitat',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: germController,
              decoration: InputDecoration(
                labelText: 'Germinades (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.eco_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx2) => AlertDialog(
                  title: const Text('Eliminar llavor?'),
                  content: Text(
                    'S\'eliminarà "${item.speciesName.isNotEmpty ? item.speciesName : item.speciesId}" de la safata.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2, false),
                      child: const Text('Cancel·lar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx2, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                if (!context.mounted) return;
                ref.read(nurseryActionsProvider.notifier).removeTrayItem(
                      tray.id,
                      tray.items,
                      index,
                    );
                Navigator.pop(ctx);
              }
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel·lar'),
          ),
          FilledButton(
            onPressed: () {
              final qty =
                  int.tryParse(qtyController.text.trim());
              if (qty == null || qty <= 0) return;
              final germ =
                  int.tryParse(germController.text.trim());

              final updated = item.copyWith(
                quantity: qty,
                germinatedCount: germ,
              );
              ref
                  .read(nurseryActionsProvider.notifier)
                  .updateTrayItem(
                    tray.id,
                    tray.items,
                    index,
                    updated,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Desar'),
          ),
        ],
      ),
    );
  }
}
