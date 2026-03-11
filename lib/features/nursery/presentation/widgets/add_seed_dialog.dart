import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../horticulture/data/repositories/hort_repository.dart';
import '../../../horticulture/domain/entities/planta_hort.dart';
import '../../domain/entities/nursery_models.dart';
import '../../presentation/providers/nursery_provider.dart';

/// Dialog to select a plant species from the hort library and add it
/// as a [TrayItem] to a specific tray.
class AddSeedDialog extends ConsumerStatefulWidget {
  final String trayId;

  const AddSeedDialog({super.key, required this.trayId});

  @override
  ConsumerState<AddSeedDialog> createState() => _AddSeedDialogState();
}

class _AddSeedDialogState extends ConsumerState<AddSeedDialog> {
  String? _selectedPlantId;
  final _qtyController = TextEditingController(text: '1');
  bool _isLoading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<PlantaHort> plants) async {
    if (_selectedPlantId == null) return;
    final plant = plants.firstWhere((p) => p.id == _selectedPlantId);
    
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) return;

    setState(() => _isLoading = true);

    try {
      final item = TrayItem(
        speciesId: plant.id,
        speciesName: plant.nomComu,
        quantity: qty,
        diesGerminacio: plant.diesGerminacio,
        diesPlanter: plant.diesPlanter,
      );
      await ref.read(nurseryActionsProvider.notifier).addTrayItem(
        widget.trayId,
        item,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error afegint llavors: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.watch(hortRepositoryProvider);

    return AlertDialog(
      title: const Text('🌱 Afegir Llavors'),
      content: StreamBuilder<List<PlantaHort>>(
        stream: repo.getPlantsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final plants = snapshot.data ?? [];
          if (plants.isEmpty) {
            return const Text(
              'No hi ha plantes a la biblioteca.\n'
              'Afegeix-ne des de l\'Hort > Biblioteca.',
            );
          }

          // Sort alphabetically
          plants.sort(
            (a, b) => a.nomComu.toLowerCase().compareTo(b.nomComu.toLowerCase()),
          );

          // Find current selected plant object for the info chip
          final currentPlant = _selectedPlantId != null 
              ? plants.where((p) => p.id == _selectedPlantId).firstOrNull 
              : null;

          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Species dropdown ---
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Espècie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.eco_outlined),
                  ),
                  isExpanded: true,
                  initialValue: _selectedPlantId,
                  items: plants.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.nomComu,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPlantId = val),
                ),
                const SizedBox(height: 16),

                // --- Quantity ---
                TextFormField(
                  controller: _qtyController,
                  decoration: InputDecoration(
                    labelText: 'Quantitat (alvèols / llavors)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                ),

                if (currentPlant != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: currentPlant.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${currentPlant.familiaBotanica} · '
                            '${currentPlant.tipusSembra.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel·lar'),
        ),
        // We pass the plants list to the submit method
        StreamBuilder<List<PlantaHort>>(
          stream: repo.getPlantsStream(),
          builder: (context, snapshot) {
            final plants = snapshot.data ?? [];
            return FilledButton.icon(
              onPressed: _isLoading || _selectedPlantId == null ? null : () => _submit(plants),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isLoading ? 'Afegint...' : 'Afegir'),
            );
          }
        ),
      ],
    );
  }
}
