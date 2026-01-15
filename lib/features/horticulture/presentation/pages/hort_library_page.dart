import 'package:flutter/material.dart';
import '../../domain/entities/planta_hort.dart';
import '../../domain/services/assistent_hort_service.dart';
import '../../data/repositories/hort_repository.dart';
import '../widgets/hort_plant_form.dart';

class HortLibraryPage extends StatefulWidget {
  final String? initialSearch;
  const HortLibraryPage({super.key, this.initialSearch});

  @override
  State<HortLibraryPage> createState() => _HortLibraryPageState();
}

class _HortLibraryPageState extends State<HortLibraryPage> {
  final _repository = HortRepository();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearch ?? '';
  }

  // Sorting state can be added later if needed.

  void _runMagicSeed() async {
    await _repository.initBibliotecaRegenerativa();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Biblioteca Regenerativa inicialitzada!'),
        ),
      );
    }
  }

  void _showMagicCheck(List<PlantaHort> plants) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => MagicCheckSheet(plants: plants),
    );
  }

  void _openPlantForm([PlantaHort? plant]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => HortPlantForm(
          plant: plant,
          // We might need to adjust HortPlantForm to accept a scroll controller
          // or just wrap in a scaffold inside the sheet.
          // Given HortPlantForm is a Scaffold, it works ok in a full-height sheet.
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca d\'Hort'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Botó Màgic (Seed Data)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Inicialitzar Biblioteca?'),
                  content: const Text(
                    'Es carregaran les dades de permacultura (Tomata, Fesol, etc.). Si ja en tens, es podrien duplicar.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel·lar'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _runMagicSeed();
                      },
                      child: const Text('Som-hi!'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        onPressed: () => _openPlantForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cerca per nom...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PlantaHort>>(
              stream: _repository.getPlantsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final plants = snapshot.data!;
                final filtered = plants
                    .where(
                      (p) => p.nomComu.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No s\'han trobat plantes.'),
                        const SizedBox(height: 16),
                        if (_searchQuery.isEmpty)
                          ElevatedButton.icon(
                            onPressed: _runMagicSeed,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Generar Dades Inicials'),
                          ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                showCheckboxColumn: false,
                                columnSpacing: 16,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey[100],
                                ),
                                columns: const [
                                  DataColumn(label: Text('Icona')),
                                  DataColumn(label: Text('Nom Comú')),
                                  DataColumn(label: Text('Nom Científic')),
                                  DataColumn(label: Text('Família')),
                                  DataColumn(label: Text('Nutrients')),
                                  DataColumn(label: Text('Marc (cm)')),
                                  DataColumn(label: Text('Aliats')),
                                  DataColumn(label: Text('Enemics')),
                                  DataColumn(label: Text('Accions')),
                                ],
                                rows: filtered
                                    .map(
                                      (p) => DataRow(
                                        onSelectChanged: (_) =>
                                            _openPlantForm(p),
                                        cells: [
                                          DataCell(
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: p.color,
                                              child: Icon(
                                                p.partComestible.icon,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              p.nomComu,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              p.nomCientific ?? '',
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(p.familiaBotanica)),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: p
                                                        .exigenciaNutrients
                                                        .color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  p.exigenciaNutrients.label,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${p.distanciaPlantacio.round()}x${p.distanciaLinies.round()}',
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                p.aliats.join(', '),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 150,
                                              child: Text(
                                                p.enemics.join(', '),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () =>
                                                  _openPlantForm(p),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'magic',
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        onPressed: () => _showMagicCheck(plants),
                        child: const Icon(Icons.compare_arrows),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MagicCheckSheet extends StatefulWidget {
  final List<PlantaHort> plants;
  const MagicCheckSheet({super.key, required this.plants});

  @override
  State<MagicCheckSheet> createState() => _MagicCheckSheetState();
}

class _MagicCheckSheetState extends State<MagicCheckSheet> {
  PlantaHort? _selectedA;
  PlantaHort? _selectedB;
  HortScore? _result;

  void _check() {
    if (_selectedA != null && _selectedB != null) {
      setState(() {
        _result = AssistentHort.validarVeinatge(_selectedA!, _selectedB!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '✨ Magic Check (Al·lelopatia)',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Planta A'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PlantaHort>(
                      value: _selectedA,
                      isExpanded: true,
                      items: widget.plants
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.nomComu),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedA = v;
                          _check();
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.compare_arrows),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Planta B'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PlantaHort>(
                      value: _selectedB,
                      isExpanded: true,
                      items: widget.plants
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.nomComu),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedB = v;
                          _check();
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_result != null) ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    _result!.status == HortStatus.aliat
                        ? Icons.favorite
                        : _result!.status == HortStatus.conflicte
                        ? Icons.warning
                        : _result!.status == HortStatus.riscFamilia
                        ? Icons.family_restroom
                        : Icons.help_outline,
                    size: 64,
                    color: _result!.score > 0
                        ? Colors.green
                        : (_result!.score < 0 ? Colors.red : Colors.orange),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _result!.reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: ${_result!.score > 0 ? "+" : ""}${_result!.score}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ] else
            const Center(
              child: Text(
                'Tria dues plantes per comprovar la seva compatibilitat.',
              ),
            ),
        ],
      ),
    );
  }
}
