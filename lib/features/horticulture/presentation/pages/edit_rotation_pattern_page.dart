import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/hort_repository.dart';
import '../../domain/entities/hort_rotation_pattern.dart';
import '../../domain/entities/planta_hort.dart';

final editPlantsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getPlantsStream();
});

class EditRotationPatternPage extends ConsumerStatefulWidget {
  final HortRotationPattern? pattern;
  const EditRotationPatternPage({super.key, this.pattern});

  @override
  ConsumerState<EditRotationPatternPage> createState() =>
      _EditRotationPatternPageState();
}

class _EditRotationPatternPageState
    extends ConsumerState<EditRotationPatternPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late List<HortRotationStage> _stages;

  @override
  void initState() {
    super.initState();
    _name = widget.pattern?.name ?? '';
    _description = widget.pattern?.description ?? '';
    _stages = List.from(widget.pattern?.stages ?? []);
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final id = widget.pattern?.id ?? const Uuid().v4();
      final newPattern = HortRotationPattern(
        id: id,
        name: _name,
        description: _description,
        stages: _stages,
      );

      await ref.read(hortRepositoryProvider).savePattern(newPattern);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Patró desat!')));
      }
    }
  }

  void _addStage() {
    setState(() {
      _stages.add(
        HortRotationStage(
          stageIndex: _stages.length,
          label: 'Nova Fase ${_stages.length + 1}',
          exigency: HortExigenciaNutrients.mitjanamentExigent,
        ),
      );
    });
  }

  void _removeStage(int index) {
    setState(() {
      _stages.removeAt(index);
      for (int i = 0; i < _stages.length; i++) {
        _stages[i] = _stages[i].copyWith(stageIndex: i);
      }
    });
  }

  Future<List<String>?> _selectPlantsBottomSheet(
    BuildContext context,
    List<String> initialSelected,
    bool isSingle,
    List<PlantaHort> allPlants,
  ) async {
    final selected = List<String>.from(initialSelected);
    return await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    isSingle ? 'Cultiu Principal' : 'Cultius Auxiliars',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allPlants.length,
                      itemBuilder: (context, index) {
                        final plant = allPlants[index];
                        final isSelected = selected.contains(plant.id);
                        return ListTile(
                          title: Text(plant.nomComu),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(Icons.circle_outlined),
                          onTap: () {
                            if (isSingle) {
                              Navigator.pop(context, [plant.id]);
                            } else {
                              setStateSheet(() {
                                if (isSelected) {
                                  selected.remove(plant.id);
                                } else {
                                  selected.add(plant.id);
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                  if (!isSingle)
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Confirmar Selecció'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(editPlantsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pattern == null ? 'Nou Patró' : 'Editar Patró'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: plantsAsync.when(
        data: (plants) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom del Patró (ex: P1 Primavera)',
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerit' : null,
                  onSaved: (v) => _name = v!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _description,
                  decoration: const InputDecoration(
                    labelText: 'Descripció breu',
                  ),
                  onSaved: (v) => _description = v ?? '',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Fases de Rotació:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                ..._stages.asMap().entries.map((e) {
                  int idx = e.key;
                  HortRotationStage stage = e.value;

                  String mainCropName = 'Cap';
                  if (stage.mainCropId != null) {
                    try {
                      mainCropName = plants
                          .firstWhere((p) => p.id == stage.mainCropId)
                          .nomComu;
                    } catch (_) {
                      mainCropName = 'Desconeguda';
                    }
                  }

                  final auxNames = stage.auxiliaryCropIds
                      .map((id) {
                        try {
                          return plants.firstWhere((p) => p.id == id).nomComu;
                        } catch (_) {
                          return 'Desconeguda';
                        }
                      })
                      .join(", ");

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: stage.label,
                                  decoration: const InputDecoration(
                                    labelText: 'Etiqueta de la Fase',
                                  ),
                                  onChanged: (v) {
                                    _stages[idx] = stage.copyWith(label: v);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeStage(idx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<HortExigenciaNutrients>(
                            initialValue: stage.exigency,
                            decoration: const InputDecoration(
                              labelText: 'Grup Cultiu (Exigència)',
                            ),
                            items: HortExigenciaNutrients.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _stages[idx] = stage.copyWith(exigency: v);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: stage.durationWeeks?.toString() ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Durada Estimat (Setmanes)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              _stages[idx] = stage.copyWith(
                                durationWeeks: int.tryParse(v),
                                durationMonths: null,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Cultiu Principal'),
                            subtitle: Text(
                              mainCropName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: const Icon(Icons.edit),
                            onTap: () async {
                              final res = await _selectPlantsBottomSheet(
                                context,
                                stage.mainCropId != null
                                    ? [stage.mainCropId!]
                                    : [],
                                true,
                                plants,
                              );
                              if (res != null && res.isNotEmpty) {
                                setState(() {
                                  _stages[idx] = stage.copyWith(
                                    mainCropId: res.first,
                                  );
                                });
                              }
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Cultius Auxiliars'),
                            subtitle: Text(auxNames.isEmpty ? 'Cap' : auxNames),
                            trailing: const Icon(Icons.edit),
                            onTap: () async {
                              final res = await _selectPlantsBottomSheet(
                                context,
                                stage.auxiliaryCropIds,
                                false,
                                plants,
                              );
                              if (res != null) {
                                setState(() {
                                  _stages[idx] = stage.copyWith(
                                    auxiliaryCropIds: res,
                                  );
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _addStage,
                  icon: const Icon(Icons.add),
                  label: const Text('Afegir Fase'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
