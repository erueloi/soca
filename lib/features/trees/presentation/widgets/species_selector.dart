import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ai_service.dart';
import '../../domain/entities/species.dart';
import '../../data/repositories/species_repository.dart';

class SpeciesSelector extends ConsumerStatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<Species> onSpeciesSelected;

  const SpeciesSelector({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.onSpeciesSelected,
  });

  @override
  ConsumerState<SpeciesSelector> createState() => _SpeciesSelectorState();
}

class _SpeciesSelectorState extends ConsumerState<SpeciesSelector> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SpeciesSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSmartAddSpeciesDialog(
    BuildContext context,
    WidgetRef ref,
    String initialQuery,
  ) async {
    final formKey = GlobalKey<FormState>();

    // 1. Smart Agent Lookup (Offline)
    final offlineMatch = ref
        .read(speciesRepositoryProvider)
        .findOfflineSpecies(initialQuery);
    final bool found = offlineMatch != null;

    // Controllers
    final commonCtrl = TextEditingController(
      text: found ? offlineMatch.commonName : '',
    );
    final sciCtrl = TextEditingController(
      text: found ? offlineMatch.scientificName : initialQuery,
    );
    final kcCtrl = TextEditingController(
      text: (offlineMatch?.kc ?? 0.7).toString(),
    );
    final fruitTypeCtrl = TextEditingController(
      text: offlineMatch?.fruitType ?? '',
    );
    final frostCtrl = TextEditingController(
      text: offlineMatch?.frostSensitivity ?? 'Mitjana',
    );
    final pruningCtrl = TextEditingController(
      text: offlineMatch?.pruningMonths.join(', ') ?? '',
    );
    final harvestCtrl = TextEditingController(
      text: offlineMatch?.harvestMonths.join(', ') ?? '',
    );

    String leaf = offlineMatch?.leafType ?? 'Caduca';
    bool fruit = offlineMatch?.fruit ?? true;
    String sunNeeds = offlineMatch?.sunNeeds ?? 'Alt';
    bool isLoadingAI = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Afegir Espècie (Cerca Intel·ligent)'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (found)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "L'agent ha trobat dades locals per '${offlineMatch.commonName}'!",
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_download,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "No trobat localment using AI...",
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            if (isLoadingAI)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.pinkAccent,
                                ),
                                onPressed: () async {
                                  setStateDialog(() => isLoadingAI = true);
                                  try {
                                    final query = sciCtrl.text.isNotEmpty
                                        ? sciCtrl.text
                                        : commonCtrl.text;
                                    if (query.isEmpty) {
                                      throw Exception(
                                        "Escriu un nom per buscar",
                                      );
                                    }

                                    final data = await ref
                                        .read(aiServiceProvider)
                                        .getBotanicalData(query);

                                    setStateDialog(() {
                                      if (data['nom_cientific'] != null &&
                                          sciCtrl.text.isEmpty) {
                                        sciCtrl.text = data['nom_cientific'];
                                      }
                                      if (data['nom_comu'] != null &&
                                          commonCtrl.text.isEmpty) {
                                        commonCtrl.text = data['nom_comu'];
                                      }
                                      if (data['kc'] != null) {
                                        kcCtrl.text = data['kc'].toString();
                                      }
                                      if (data['fulla'] != null) {
                                        leaf = data['fulla'] == 'Perenne'
                                            ? 'Perenne'
                                            : 'Caduca';
                                      }
                                      if (data['sensibilitat_gelada'] != null) {
                                        frostCtrl.text =
                                            data['sensibilitat_gelada'];
                                      }
                                      if (data['mesos_poda'] != null) {
                                        pruningCtrl.text =
                                            (data['mesos_poda'] as List).join(
                                              ', ',
                                            );
                                      }
                                      if (data['mesos_collita'] != null) {
                                        harvestCtrl.text =
                                            (data['mesos_collita'] as List)
                                                .join(', ');
                                      }
                                      if (data['sol'] != null) {
                                        final s = data['sol'].toString();
                                        if (s.contains('☀️')) sunNeeds = 'Alt';
                                        if (s.contains('🌤️')) {
                                          sunNeeds = 'Mitjà';
                                        }
                                        if (s.contains('☁️')) {
                                          sunNeeds = 'Baix';
                                        }
                                      }
                                      if (data['fruit'] != null) {
                                        fruit = data['fruit'] == true;
                                      }
                                      if (data['nom_fruit'] != null) {
                                        fruitTypeCtrl.text = data['nom_fruit'];
                                        if (fruitTypeCtrl.text.isNotEmpty) {
                                          fruit = true;
                                        }
                                      }
                                      isLoadingAI = false;
                                    });
                                  } catch (e) {
                                    setStateDialog(() => isLoadingAI = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error IA: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: commonCtrl,
                      decoration: const InputDecoration(labelText: 'Nom Comú'),
                      validator: (v) => v!.isEmpty ? 'Cal un nom' : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: sciCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nom Científic (Opcional)',
                            ),
                          ),
                        ),
                        if (!found && !isLoadingAI)
                          IconButton(
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Colors.pinkAccent,
                            ),
                            tooltip: 'Omplir dades amb IA',
                            onPressed: () {
                              // Duplicate logic trigger if needed, or rely on top button
                            },
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: kcCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kc (Coeficient)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(sunNeeds),
                            initialValue: sunNeeds,
                            decoration: const InputDecoration(labelText: 'Sol'),
                            items: ['Alt', 'Mitjà', 'Baix']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setStateDialog(() => sunNeeds = v!),
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(leaf),
                      initialValue: leaf,
                      decoration: const InputDecoration(labelText: 'Fulla'),
                      items: ['Perenne', 'Caduca']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() => leaf = v!),
                    ),
                    TextFormField(
                      controller: frostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sensibilitat Gelada',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: pruningCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos de Poda (ex: 12, 1, 2)',
                        hintText: 'Mesos separats per comes',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: harvestCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos de Collita (ex: 9, 10)',
                        hintText: 'Mesos separats per comes',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    CheckboxListTile(
                      title: const Text('Té Fruit?'),
                      value: fruit,
                      onChanged: (v) {
                        setStateDialog(() => fruit = v ?? false);
                      },
                    ),
                    if (fruit)
                      TextFormField(
                        controller: fruitTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom del Fruit (ex: Poma)',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('TANCAR'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    // Parse months
                    List<int> parseMonths(String text) {
                      return text
                          .split(',')
                          .map((e) => int.tryParse(e.trim()) ?? 0)
                          .where((e) => e >= 1 && e <= 12)
                          .toList();
                    }

                    final newSpecies = Species(
                      id: '',
                      commonName: commonCtrl.text,
                      scientificName: sciCtrl.text.isEmpty
                          ? commonCtrl.text
                          : sciCtrl.text, // Fallback
                      kc: double.tryParse(kcCtrl.text) ?? 0.7,
                      leafType: leaf,
                      frostSensitivity: frostCtrl.text,
                      fruit: fruit,
                      fruitType: fruit ? fruitTypeCtrl.text : null,
                      sunNeeds: sunNeeds,
                      pruningMonths: parseMonths(pruningCtrl.text),
                      harvestMonths: parseMonths(harvestCtrl.text),
                      color: '4CAF50',
                    );

                    // Add to Repo and get ID
                    final newId = await ref
                        .read(speciesRepositoryProvider)
                        .addSpecies(newSpecies);

                    final createdSpecies = newSpecies.copyWith(id: newId);

                    // Select it in parent
                    if (context.mounted) {
                      Navigator.pop(context);
                      widget.onSpeciesSelected(
                        createdSpecies.copyWith(id: newId),
                      );
                    }
                  }
                },
                child: const Text('GUARDAR I SELECCIONAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesRepositoryProvider).getSpecies();

    return StreamBuilder<List<Species>>(
      stream: speciesAsync,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final speciesList = snapshot.data ?? [];

        return Autocomplete<Species>(
          initialValue: TextEditingValue(text: _controller.text),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase();
            final matches = speciesList.where((s) {
              return s.commonName.toLowerCase().contains(query) ||
                  s.scientificName.toLowerCase().contains(query);
            });

            final sentinel = Species(
              id: 'SMART_ADD_SENTINEL',
              commonName: 'Afegir nou...',
              scientificName: 'Afegir nou...',
              kc: 0,
              leafType: '',
              frostSensitivity: '',
              fruit: false,
              color: '4CAF50',
            );

            return [...matches, sentinel];
          },
          displayStringForOption: (Species option) {
            if (option.id == 'SMART_ADD_SENTINEL') {
              return _controller.text;
            }
            return option.scientificName;
          },
          onSelected: (Species selection) {
            if (selection.id == 'SMART_ADD_SENTINEL') {
              // Trigger smart add
              _showSmartAddSpeciesDialog(context, ref, _controller.text);
            } else {
              _controller.text = selection.scientificName;
              widget.onSpeciesSelected(selection);
            }
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                if (_controller.text != textEditingController.text) {
                  textEditingController.text = _controller.text;
                }
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Espècie (Científic)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    _controller.text = val;
                    widget.onChanged(val);
                  },
                  validator: (v) => v!.isEmpty ? 'Cal posar l\'espècie' : null,
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Species option = options.elementAt(index);
                      if (option.id == 'SMART_ADD_SENTINEL') {
                        return ListTile(
                          leading: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          title: Text(
                            'Afegir "${_controller.text}" a la Biblioteca...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            _showSmartAddSpeciesDialog(
                              context,
                              ref,
                              _controller.text,
                            );
                          },
                        );
                      }
                      return ListTile(
                        title: Text(option.commonName),
                        subtitle: Text(option.scientificName),
                        trailing: Text("Kc: ${option.kc}"),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
