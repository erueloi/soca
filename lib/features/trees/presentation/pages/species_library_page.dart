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
  int? _sortColumnIndex;
  bool _sortAscending = true;

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

  void _sort<T>(
    Comparable<T> Function(Species d) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
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
    // New Fields
    final plantingCtrl = TextEditingController(
      text: formatList(existing?.plantingMonths),
    );
    final heightCtrl = TextEditingController(
      text: (existing?.adultHeight ?? 0.0).toString(),
    );
    final diameterCtrl = TextEditingController(
      text: (existing?.adultDiameter ?? 0.0).toString(),
    );

    // State Variables
    String leaf = existing?.leafType ?? 'Caduca';
    String sunNeeds = existing?.sunNeeds ?? 'Alt';

    // New State
    String growthRate = existing?.growthRate ?? 'Mig'; // Lent, Mig, Ràpid
    int droughtResistance = existing?.droughtResistance ?? 3; // 1-5

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

                                      // New: Extended Data
                                      if (data['alcada_adulta'] != null) {
                                        heightCtrl.text = data['alcada_adulta']
                                            .toString();
                                      }
                                      if (data['diametre_adult'] != null) {
                                        diameterCtrl.text =
                                            data['diametre_adult'].toString();
                                      }
                                      if (data['ritme_creixement'] != null) {
                                        final r = data['ritme_creixement'];
                                        if ([
                                          'Lent',
                                          'Mig',
                                          'Ràpid',
                                        ].contains(r)) {
                                          growthRate = r;
                                        }
                                      }
                                      if (data['resistencia_sequera'] != null) {
                                        droughtResistance =
                                            data['resistencia_sequera'];
                                      }
                                      if (data['mesos_plantacio'] != null) {
                                        plantingCtrl.text =
                                            (data['mesos_plantacio'] as List)
                                                .join(', ');
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
                            decoration: const InputDecoration(labelText: 'Kc'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('sun_$sunNeeds'),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('growth_$growthRate'),
                            initialValue: growthRate,
                            decoration: const InputDecoration(
                              labelText: 'Creixement',
                            ),
                            items: ['Lent', 'Mig', 'Ràpid']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setStateDialog(() => growthRate = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('leaf_$leaf'),
                            initialValue: leaf,
                            decoration: const InputDecoration(
                              labelText: 'Fulla',
                            ),
                            items: ['Perenne', 'Caduca']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setStateDialog(() => leaf = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sequera ($droughtResistance/5)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Slider(
                                value: droughtResistance.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: droughtResistance.toString(),
                                onChanged: (v) => setStateDialog(
                                  () => droughtResistance = v.toInt(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: frostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sensibilitat Gelada',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: heightCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Alçada (m)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: diameterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ø Adult (m)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: plantingCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos Plantació (ex: 3, 4)',
                        prefixIcon: Icon(Icons.calendar_month, size: 16),
                      ),
                    ),
                    TextFormField(
                      controller: pruningCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos Poda (ex: 12, 1)',
                        prefixIcon: Icon(Icons.cut, size: 16),
                      ),
                    ),
                    TextFormField(
                      controller: harvestCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mesos Collita (ex: 9, 10)',
                        prefixIcon: Icon(Icons.shopping_basket, size: 16),
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
                      plantingMonths: parseMonths(plantingCtrl.text),
                      color: selectedColor,
                      iconCode: selectedIconCode,
                      iconName: selectedIconName, // Persist the name
                      iconFamily: selectedIconFamily,
                      adultHeight: double.tryParse(heightCtrl.text) ?? 0.0,
                      adultDiameter: double.tryParse(diameterCtrl.text) ?? 0.0,
                      growthRate: growthRate,
                      droughtResistance: droughtResistance,
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

  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Llegenda'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                Icons.wb_sunny,
                'Necessitat de Sol',
                '☀️ (Alt), 🌤️ (Mitjà), ☁️ (Baix)',
              ),
              const Divider(),
              _buildLegendItem(
                Icons.ac_unit,
                'Sensibilitat a Gelades',
                '❄️❄️❄️ (Alta), ❄️❄️ (Mitjana), ❄️ (Baixa)',
              ),
              const Divider(),
              _buildLegendItem(
                Icons.cut,
                'Mesos de Poda',
                'Mesos ideals per podar (ex: Gen, Feb)',
              ),
              const Divider(),
              _buildLegendItem(
                Icons.shopping_basket,
                'Mesos de Collita',
                'Mesos de recol·lecció del fruit',
              ),
              const Divider(),
              _buildLegendItem(
                Icons.apple,
                'Fruit',
                'Si produeix fruit comestible/aprofit.',
              ),
              const Divider(),
              _buildLegendItem(Icons.height, 'Alçada Adulta', 'En metres (m)'),
              const Divider(),
              _buildLegendItem(
                Icons.circle_outlined,
                'Diàmetre',
                'En metres (m)',
              ),
              const Divider(),
              _buildLegendItem(Icons.speed, 'Creixement', 'Lent, Mig o Ràpid'),
              const Divider(),
              _buildLegendItem(
                Icons.calendar_month,
                'Mesos Plantació',
                'Època ideal',
              ),
              const Divider(),
              _buildLegendItem(
                Icons.water_drop,
                'Resistència Sequera',
                'De 1 (Poca) a 5 (Molta)',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TANCAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.indigo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(desc, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speciesStream = ref.watch(speciesRepositoryProvider).getSpecies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca d\'Espècies'),
        actions: [
          if (_sortColumnIndex != null)
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restablir ordre original',
              onPressed: () {
                setState(() {
                  _sortColumnIndex = null;
                  _sortAscending = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Llegenda',
            onPressed: _showLegendDialog,
          ),
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
              decoration: InputDecoration(
                labelText: 'Cercar...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
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
                var filtered = allSpecies.where((s) {
                  final q = _searchQuery; // Already lowercased in onChanged
                  return s.commonName.toLowerCase().contains(q) ||
                      s.scientificName.toLowerCase().contains(q) ||
                      s.prefix.toLowerCase().contains(q) ||
                      (s.fruitType ?? '').toLowerCase().contains(q);
                }).toList();

                if (_sortColumnIndex != null) {
                  filtered.sort((a, b) {
                    int cmp = 0;
                    switch (_sortColumnIndex) {
                      case 0:
                        cmp = a.commonName.compareTo(b.commonName);
                        break;
                      case 4:
                        cmp = a.scientificName.compareTo(b.scientificName);
                        break;
                      case 5:
                        cmp = a.kc.compareTo(b.kc);
                        break;
                      case 11:
                        cmp = a.adultHeight.compareTo(b.adultHeight);
                        break;
                      case 12:
                        cmp = a.adultDiameter.compareTo(b.adultDiameter);
                        break;
                      case 13:
                        const map = {'Lent': 1, 'Mig': 2, 'Ràpid': 3};
                        final va = map[a.growthRate] ?? 0;
                        final vb = map[b.growthRate] ?? 0;
                        cmp = va.compareTo(vb);
                        break;
                      case 14:
                        final ma = a.plantingMonths.isEmpty
                            ? 99
                            : a.plantingMonths.first;
                        final mb = b.plantingMonths.isEmpty
                            ? 99
                            : b.plantingMonths.first;
                        cmp = ma.compareTo(mb);
                        break;
                      case 15:
                        cmp = a.droughtResistance.compareTo(
                          b.droughtResistance,
                        );
                        break;
                    }
                    return _sortAscending ? cmp : -cmp;
                  });
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text('Cap espècie trobada.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columnSpacing: 20,
                      columns: [
                        DataColumn(
                          label: const Text('Nom Comú'),
                          onSort: (idx, asc) =>
                              _sort<String>((d) => d.commonName, idx, asc),
                        ),
                        const DataColumn(label: Text('Icona')),
                        const DataColumn(label: Text('Color')),
                        const DataColumn(
                          label: Text(
                            'Cod.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: const Text('Científic'),
                          onSort: (idx, asc) =>
                              _sort<String>((d) => d.scientificName, idx, asc),
                        ),
                        DataColumn(
                          label: const Text('Kc'),
                          onSort: (idx, asc) =>
                              _sort<num>((d) => d.kc, idx, asc),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Necessitat de Sol',
                            child: Icon(
                              Icons.wb_sunny,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Sensibilitat a Gelades',
                            child: Icon(
                              Icons.ac_unit,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Mesos de Poda',
                            child: Icon(
                              Icons.cut,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Mesos de Collita',
                            child: Icon(
                              Icons.shopping_basket,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Fruit Comestible/Aprofitable',
                            child: Icon(
                              Icons.apple,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Tooltip(
                            message: 'Alçada Adulta (m)',
                            child: Icon(
                              Icons.height,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                          onSort: (idx, asc) =>
                              _sort<num>((d) => d.adultHeight, idx, asc),
                        ), // Height
                        DataColumn(
                          label: Tooltip(
                            message: 'Diàmetre Adult (m)',
                            child: Icon(
                              Icons.circle_outlined,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                          onSort: (idx, asc) =>
                              _sort<num>((d) => d.adultDiameter, idx, asc),
                        ), // Diameter
                        DataColumn(
                          label: Tooltip(
                            message: 'Ritme de Creixement',
                            child: Icon(
                              Icons.speed,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                          onSort: (idx, asc) =>
                              _sort<String>((d) => d.growthRate, idx, asc),
                        ), // Growth
                        DataColumn(
                          label: Tooltip(
                            message: 'Mesos Plantació',
                            child: Icon(
                              Icons.calendar_month,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                          onSort: (idx, asc) => _sort<num>(
                            (d) => d.plantingMonths.isEmpty
                                ? 99
                                : d.plantingMonths.first,
                            idx,
                            asc,
                          ),
                        ), // Planting
                        DataColumn(
                          label: Tooltip(
                            message: 'Resistència Sequera',
                            child: Icon(
                              Icons.water_drop,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                          onSort: (idx, asc) =>
                              _sort<num>((d) => d.droughtResistance, idx, asc),
                        ), // Drought
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
                            DataCell(Text('${s.adultHeight}m')),
                            DataCell(Text('${s.adultDiameter}m')),
                            DataCell(Text(s.growthRate)),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _formatMonths(s.plantingMonths),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < s.droughtResistance
                                        ? Icons.water_drop
                                        : Icons.water_drop_outlined,
                                    size: 12,
                                    color: Colors.blueAccent,
                                  ),
                                ),
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
