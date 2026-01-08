import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/species_repository.dart';
import '../../domain/entities/species.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/utils/icon_utils.dart';

class SpeciesLibraryPage extends ConsumerStatefulWidget {
  final String? initialSearchQuery;
  const SpeciesLibraryPage({super.key, this.initialSearchQuery});

  @override
  ConsumerState<SpeciesLibraryPage> createState() => _SpeciesLibraryPageState();
}

class _SpeciesLibraryPageState extends ConsumerState<SpeciesLibraryPage> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  Future<MapEntry<String, IconData>?> _showBotanicalPicker(
    BuildContext context,
  ) async {
    return showDialog<MapEntry<String, IconData>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tria una icona'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 60,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: IconUtils.botanicalIcons.length,
            itemBuilder: (context, index) {
              final entry = IconUtils.botanicalIcons.entries.elementAt(index);
              return InkWell(
                onTap: () => Navigator.pop(ctx, entry),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.value, size: 32, color: Colors.green),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tancar'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSpeciesDialog([Species? existing]) {
    final formKey = GlobalKey<FormState>();

    // Controllers
    final commonCtrl = TextEditingController(text: existing?.commonName ?? '');
    final sciCtrl = TextEditingController(text: existing?.scientificName ?? '');
    final kcCtrl = TextEditingController(
      text: (existing?.kc ?? 0.7).toString(),
    );
    final prefixCtrl = TextEditingController(text: existing?.prefix ?? '');
    final fruitTypeCtrl = TextEditingController(
      text: existing?.fruitType ?? '',
    );
    final frostCtrl = TextEditingController(
      text: existing?.frostSensitivity ?? 'Baixa',
    );
    // Helper to format months
    String formatList(List<int>? l) => l?.join(', ') ?? '';
    final pruningCtrl = TextEditingController(
      text: formatList(existing?.pruningMonths),
    );
    final harvestCtrl = TextEditingController(
      text: formatList(existing?.harvestMonths),
    );

    // State Variables
    String leaf = existing?.leafType ?? 'Caduca';
    String sunNeeds = existing?.sunNeeds ?? 'Alt';
    bool fruit = existing?.fruit ?? true;
    String selectedColor = (existing?.color ?? '4CAF50').replaceAll('#', '');
    int? selectedIconCode = existing?.iconCode;
    String? selectedIconName = existing?.iconName;
    String? selectedIconFamily = existing?.iconFamily;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    existing == null ? 'Afegir Espècie' : 'Editar Espècie',
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: commonCtrl,
                      decoration: const InputDecoration(labelText: 'Nom Comú'),
                      validator: (v) => v!.isEmpty ? 'Cal un nom' : null,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: sciCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nom Científic (Prioritari)',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.indigo,
                          ),
                          tooltip: 'Omplir amb IA',
                          onPressed: isLoading
                              ? null
                              : () async {
                                  // Prioritize Sci Name, fallback to Common
                                  final query = sciCtrl.text.isNotEmpty
                                      ? sciCtrl.text
                                      : commonCtrl.text;

                                  if (query.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Escriu un nom per buscar',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setStateDialog(() => isLoading = true);

                                  try {
                                    final data = await ref
                                        .read(aiServiceProvider)
                                        .getBotanicalData(query);

                                    setStateDialog(() {
                                      // Update Names if missing/different
                                      if (data['nom_cientific'] != null &&
                                          sciCtrl.text.isEmpty) {
                                        sciCtrl.text = data['nom_cientific'];
                                      }
                                      if (data['nom_comu'] != null &&
                                          commonCtrl.text.isEmpty) {
                                        commonCtrl.text = data['nom_comu'];
                                      }

                                      // Update Controllers & State
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
                                      // New: Visuals
                                      if (data['color'] != null) {
                                        selectedColor = data['color']
                                            .toString()
                                            .replaceAll('#', '');
                                      }
                                      if (data['iconCode'] != null) {
                                        selectedIconCode = data['iconCode'];
                                      }
                                      isLoading = false;
                                    });
                                  } catch (e) {
                                    setStateDialog(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error IA: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: prefixCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prefix (3 Lletres)',
                        hintText: 'EX: OLI',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Color del Marcador',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Pro Color Picker Trigger
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tria el color'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: Color(
                                  int.parse('0xFF$selectedColor'),
                                ),
                                onColorChanged: (color) {
                                  // Update state with valid Hex string (no alpha)
                                  final hex = color
                                      .toARGB32()
                                      .toRadixString(16)
                                      .toUpperCase()
                                      .substring(2);
                                  setStateDialog(() => selectedColor = hex);
                                },
                                enableAlpha: false,
                                displayThumbColor: true,
                                labelTypes: const [
                                  ColorLabelType.hex,
                                  ColorLabelType.rgb,
                                  ColorLabelType.hsv,
                                ],
                                paletteType: PaletteType.hsvWithHue,
                                pickerAreaHeightPercent: 0.8,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Fet'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(int.parse('0xFF$selectedColor')),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Color del Marcador',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('#$selectedColor'),
                                ],
                              ),
                            ),
                            const Icon(Icons.colorize),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    const Text(
                      'Icona del Mapa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // 1. Quick Select Row (Botanical Filter)
                    // 1. Quick Select Row (Botanical Filter)
                    Builder(
                      builder: (context) {
                        final List<IconData> defaultIcons = [
                          Icons.park,
                          Icons.nature,
                          Icons.forest,
                          Icons.grass,
                          Icons.local_florist,
                          Icons.agriculture,
                          Icons.spa,
                          Icons.eco,
                        ];

                        final displayIcons = List<IconData>.from(defaultIcons);
                        if (selectedIconCode != null &&
                            !defaultIcons.any(
                              (i) => i.codePoint == selectedIconCode,
                            )) {
                          displayIcons.add(
                            IconUtils.resolveIcon(
                              selectedIconCode!,
                              selectedIconFamily,
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: displayIcons.map((icon) {
                            final isSelected =
                                selectedIconCode == icon.codePoint;
                            return GestureDetector(
                              onTap: () => setStateDialog(
                                () => selectedIconCode = icon.codePoint,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.green.shade100
                                          : Colors.grey.shade100,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. Full Library Search
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search),
                        label: Text(
                          selectedIconCode != null
                              ? 'Cercar una altra icona...' // "Search another..."
                              : 'Cercar a la llibreria completa',
                        ), // "Search full library"
                        onPressed: () async {
                          final result = await _showBotanicalPicker(context);

                          if (result != null) {
                            setStateDialog(() {
                              selectedIconCode = result.value.codePoint;
                              selectedIconName = result.key;
                              selectedIconFamily = result.value.fontFamily;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // UI logic is now inline above.
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
                    TextFormField(
                      controller: pruningCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos Poda (ex: 12, 1)',
                      ),
                    ),
                    TextFormField(
                      controller: harvestCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos Collita (ex: 9, 10)',
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('Té Fruit?'),
                      value: fruit,
                      onChanged: (v) =>
                          setStateDialog(() => fruit = v ?? false),
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
                child: const Text('CANCEL·LAR'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    // Helper to parse months
                    List<int> parseMonths(String t) => t
                        .split(',')
                        .map((e) => int.tryParse(e.trim()) ?? 0)
                        .where((e) => e > 0)
                        .toList();

                    final newSpecies = Species(
                      id: existing?.id ?? '',
                      commonName: commonCtrl.text,
                      scientificName: sciCtrl.text,
                      kc: double.tryParse(kcCtrl.text) ?? 0.7,
                      leafType: leaf,
                      frostSensitivity: frostCtrl.text,
                      fruit: fruit,
                      fruitType: fruit ? fruitTypeCtrl.text : null,
                      sunNeeds: sunNeeds,
                      prefix: prefixCtrl.text.toUpperCase(),
                      pruningMonths: parseMonths(pruningCtrl.text),
                      harvestMonths: parseMonths(harvestCtrl.text),
                      color: selectedColor,
                      iconCode: selectedIconCode,
                      iconName: selectedIconName, // Persist the name
                      iconFamily: selectedIconFamily,
                    );

                    if (existing == null) {
                      await ref
                          .read(speciesRepositoryProvider)
                          .addSpecies(newSpecies);
                    } else {
                      await ref
                          .read(speciesRepositoryProvider)
                          .updateSpecies(newSpecies);
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatMonths(List<int> months) {
    if (months.isEmpty) return '-';
    months.sort();
    // Simple logic: if contiguous (allowing wrap 12->1), show range.
    // Full logic is complex, let's just list short names for now or simplified range.
    const names = [
      '',
      'Gen',
      'Feb',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Oct',
      'Nov',
      'Des',
    ];
    return months.map((m) => names[m]).join(', ');
  }

  String _getSunIcon(String needs) {
    switch (needs.toLowerCase()) {
      case 'alt':
        return '☀️';
      case 'mitjà':
        return '🌤️';
      case 'baix':
        return '☁️';
      default:
        return '☀️';
    }
  }

  String _getFrostIcon(String sensitivity) {
    final s = sensitivity.toLowerCase();
    if (s.contains('alta')) return '❄️❄️❄️';
    if (s.contains('mitjana')) return '❄️❄️';
    if (s.contains('baixa')) return '❄️';
    if (s.contains('baixa')) return '❄️';
    return sensitivity;
  }

  @override
  Widget build(BuildContext context) {
    final speciesStream = ref.watch(speciesRepositoryProvider).getSpecies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca d\'Espècies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Carregar Inicials (Lleida)',
            onPressed: () async {
              await ref.read(speciesRepositoryProvider).seedLibrary();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'S\'ha intentat carregar les dades inicials.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cercar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Species>>(
              stream: speciesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allSpecies = snapshot.data ?? [];
                final filtered = allSpecies.where((s) {
                  return s.commonName.toLowerCase().contains(_searchQuery) ||
                      s.scientificName.toLowerCase().contains(_searchQuery) ||
                      (s.fruitType ?? '').toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Cap espècie trobada.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Nom Comú')),
                        DataColumn(label: Text('Icona')),
                        DataColumn(label: Text('Color')),
                        DataColumn(
                          label: Text(
                            'Cod.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(label: Text('Científic')),
                        DataColumn(label: Text('Kc')),
                        DataColumn(label: Text('Sol')),
                        DataColumn(label: Text('Gelada')),
                        DataColumn(label: Text('Poda')),
                        DataColumn(label: Text('Collita')),
                        DataColumn(label: Text('Fruit')),
                      ],
                      rows: filtered.map((s) {
                        Color speciesColor = Colors.grey;
                        if (s.color.isNotEmpty) {
                          try {
                            speciesColor = Color(
                              int.parse('0xFF${s.color.replaceAll('#', '')}'),
                            );
                          } catch (_) {}
                        }

                        IconData icon = Icons.help_outline;
                        if (s.iconCode != null) {
                          icon = IconUtils.resolveIcon(
                            s.iconCode!,
                            s.iconFamily,
                          );
                        }

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                s.commonName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(Icon(icon, size: 20)),
                            DataCell(
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: speciesColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(s.prefix)),
                            DataCell(
                              Text(
                                s.scientificName,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            DataCell(Text(s.kc.toString())),
                            DataCell(Text(_getSunIcon(s.sunNeeds))),
                            DataCell(Text(_getFrostIcon(s.frostSensitivity))),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _formatMonths(s.pruningMonths),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _formatMonths(s.harvestMonths),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                s.fruitType?.isNotEmpty == true
                                    ? s.fruitType!
                                    : (s.fruit ? 'Sí' : '-'),
                              ),
                            ),
                          ],
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              _showAddSpeciesDialog(s);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSpeciesDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
