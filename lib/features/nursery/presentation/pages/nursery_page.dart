import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/nursery_models.dart';
import '../../presentation/providers/nursery_provider.dart';
import '../widgets/kanban_column.dart';
import '../widgets/add_tray_sheet.dart';

/// Configuration for each active Kanban column.
class _KanbanColumnConfig {
  final TrayStatus status;
  final String title;
  final IconData icon;
  final Color color;

  const _KanbanColumnConfig({
    required this.status,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class NurseryPage extends ConsumerWidget {
  const NurseryPage({super.key});

  /// Active columns (archived is excluded from the board).
  static const _columns = [
    _KanbanColumnConfig(
      status: TrayStatus.germination,
      title: '🌑 Germinació',
      icon: Icons.dark_mode_outlined,
      color: Color(0xFF6D4C41), // Brown
    ),
    _KanbanColumnConfig(
      status: TrayStatus.growing,
      title: '☀️ Creixement',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFF558B2F), // Green
    ),
    _KanbanColumnConfig(
      status: TrayStatus.hardening,
      title: '🌬️ Enduriment',
      icon: Icons.air,
      color: Color(0xFF0277BD), // Blue
    ),
    _KanbanColumnConfig(
      status: TrayStatus.ready,
      title: '🚀 Llesta',
      icon: Icons.rocket_launch_outlined,
      color: Color(0xFFE65100), // Deep Orange
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traysAsync = ref.watch(nurseryTraysStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🌱 Incubadora / Planter')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTraySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Safata'),
      ),
      body: traysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error carregant safates: $err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allTrays) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return _buildWideLayout(allTrays);
            } else {
              return _buildMobileLayout(allTrays);
            }
          },
        ),
      ),
    );
  }

  /// Wide (Web / Tablet): 4 columns side by side in a Row.
  Widget _buildWideLayout(List<SeedTray> allTrays) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _columns.map((col) {
          final filtered =
              allTrays.where((t) => t.status == col.status).toList();
          return Expanded(
            child: KanbanColumn(
              title: col.title,
              icon: col.icon,
              color: col.color,
              trays: filtered,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Mobile: Horizontal scroll with PageView-like snapping.
  Widget _buildMobileLayout(List<SeedTray> allTrays) {
    return PageView.builder(
      controller: PageController(viewportFraction: 0.85),
      itemCount: _columns.length,
      itemBuilder: (context, index) {
        final col = _columns[index];
        final filtered =
            allTrays.where((t) => t.status == col.status).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: KanbanColumn(
            title: col.title,
            icon: col.icon,
            color: col.color,
            trays: filtered,
          ),
        );
      },
    );
  }

  void _showAddTraySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddTraySheet(),
    );
  }
}
