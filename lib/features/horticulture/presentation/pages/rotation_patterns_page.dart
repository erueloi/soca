import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/hort_repository.dart';
import 'edit_rotation_pattern_page.dart';

// Stream Provider for Patterns
final rotationPatternsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getPatternsStream();
});

// Stream Provider for Plants (Local reused or global)
final plantsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getPlantsStream();
});

class RotationPatternsPage extends ConsumerWidget {
  final String? initialPatternId;
  const RotationPatternsPage({super.key, this.initialPatternId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(rotationPatternsStreamProvider);
    final plantsAsync = ref.watch(plantsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrons de Rotació'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger seed if empty (Temporary helper)
              ref.read(hortRepositoryProvider).initRotationPatterns();
            },
            tooltip: 'Inicialitzar Patrons Base',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => const EditRotationPatternPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: patternsAsync.when(
        data: (patterns) {
          return plantsAsync.when(
            data: (plants) {
              if (patterns.isEmpty) {
                return const Center(
                  child: Text(
                    'No hi ha patrons. Prem el botó de refrescar per carregar els base.',
                  ),
                );
              }
              return ListView.builder(
                itemCount: patterns.length,
                itemBuilder: (context, index) {
                  final pattern = patterns[index];
                  final isInitial = pattern.id == initialPatternId;

                  return Card(
                    color: isInitial ? Colors.orange.shade50 : null,
                    shape: isInitial
                        ? RoundedRectangleBorder(
                            side: const BorderSide(
                              color: Colors.deepOrange,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: isInitial,
                      title: Text(
                        pattern.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(pattern.description),
                      leading: CircleAvatar(
                        child: Text(pattern.id.substring(0, 1)), // O or P
                      ),
                      children: [
                        ...pattern.stages.map((stage) {
                          String mainCropName = 'Cap';
                          if (stage.mainCropId != null) {
                            try {
                              mainCropName = plants
                                  .firstWhere((p) => p.id == stage.mainCropId)
                                  .nomComu;
                            } catch (_) {
                              mainCropName = stage.mainCropId!;
                            }
                          }

                          final auxNames = stage.auxiliaryCropIds
                              .map((id) {
                                try {
                                  return plants
                                      .firstWhere((p) => p.id == id)
                                      .nomComu;
                                } catch (_) {
                                  return id;
                                }
                              })
                              .join(", ");

                          String auxText = auxNames.isNotEmpty
                              ? ' | Aux: $auxNames'
                              : '';
                          String durationText = stage.durationWeeks != null
                              ? ' (${stage.durationWeeks} setm.)'
                              : ' (${stage.durationMonths} mesos)';

                          return ListTile(
                            leading: Chip(
                              label: Text((stage.stageIndex + 1).toString()),
                              backgroundColor: stage.exigency.color.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            title: Text('${stage.label}$durationText'),
                            subtitle: Text(
                              '${stage.exigency.label}\nPrincipal: $mainCropName$auxText',
                            ),
                            isThreeLine: true,
                          );
                        }),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar Patró'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => EditRotationPatternPage(
                                      pattern: pattern,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading plants: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
