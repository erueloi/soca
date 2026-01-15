import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/repositories/hort_repository.dart';
import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/garden_layout_config.dart';
import 'garden_designer_page.dart';

final espaiListStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(hortRepositoryProvider);
  return repo.getEspaisStream();
});

class EspaiListPage extends ConsumerStatefulWidget {
  const EspaiListPage({super.key});

  @override
  ConsumerState<EspaiListPage> createState() => _EspaiListPageState();
}

class _EspaiListPageState extends ConsumerState<EspaiListPage> {
  String? _loadingId;

  @override
  Widget build(BuildContext context) {
    final espaisAsync = ref.watch(espaiListStreamProvider);

    return Scaffold(
      body: espaisAsync.when(
        data: (espais) {
          if (espais.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_on, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No tens cap espai creat.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Nou Espai'),
                    onPressed: () => _showCreateDialog(context, ref),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: espais.length,
                itemBuilder: (context, index) {
                  final espai = espais[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.grass,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              espai.nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${espai.width}m x ${espai.length}m  |  ${espai.layoutConfig?.numberOfBeds ?? '?'} Bancals',
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GardenDesignerPage(espai: espai),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: _loadingId == espai.id
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.edit, size: 18),
                                label: Text(
                                  _loadingId == espai.id
                                      ? 'Obrint...'
                                      : 'Dissenyar',
                                  style: TextStyle(
                                    color: _loadingId == espai.id
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                                onPressed: _loadingId == espai.id
                                    ? null
                                    : () async {
                                        setState(() => _loadingId = espai.id);
                                        await Future.delayed(Duration.zero);

                                        if (!context.mounted) return;
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => GardenDesignerPage(
                                              espai: espai,
                                            ),
                                          ),
                                        );
                                        if (mounted) {
                                          setState(() => _loadingId = null);
                                        }
                                      },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () =>
                                    _showDeleteDialog(context, ref, espai),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () => _showCreateDialog(context, ref),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    // Controllers for Layout Wizard
    final nameCtrl = TextEditingController();
    final widthCtrl = TextEditingController(text: '7');
    final lengthCtrl = TextEditingController(text: '5');
    final numBedsCtrl = TextEditingController(text: '4');
    final pathWidthCtrl = TextEditingController(text: '0.5');
    final cellSizeCtrl = TextEditingController(text: '0.2');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Validation Logic
          bool isValid =
              nameCtrl.text.isNotEmpty &&
              (double.tryParse(widthCtrl.text) ?? 0) > 0 &&
              (double.tryParse(lengthCtrl.text) ?? 0) > 0 &&
              (int.tryParse(numBedsCtrl.text) ?? 0) > 0 &&
              (double.tryParse(pathWidthCtrl.text) ?? 0) >= 0;

          // Calculation
          Widget feedbackWidget = const SizedBox.shrink();
          final w = double.tryParse(widthCtrl.text) ?? 0;
          final n = int.tryParse(numBedsCtrl.text) ?? 0;
          final p = double.tryParse(pathWidthCtrl.text) ?? 0;

          if (w > 0 && n > 0 && p >= 0) {
            final totalPath = (n + 1) * p;
            final totalBed = w - totalPath;
            if (totalBed <= 0) {
              isValid = false;
              feedbackWidget = Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Massa estret! No hi caben els bancals.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              final bedW = totalBed / n;
              feedbackWidget = Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9), // Light Green
                  border: Border(
                    bottom: BorderSide(color: Colors.green[800]!, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_box, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Amplada de cada bancal: ${bedW.toStringAsFixed(2)} m',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text('Nou Espai d\'Hort'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'Espai',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dimensions Totals',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amplada (m)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lengthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Llargada (m)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Distribució de Bancals',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.blue.withValues(alpha: 0.1),
                      child: const Text(
                        'Fórmula N+1: Es calcularà automàticament l\'amplada dels bancals tenint en compte passadissos a tots els costats.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: numBedsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Núm. Bancals',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: pathWidthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amplada Passadís',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller:
                          cellSizeCtrl, // Make sure to define this controller above!
                      decoration: const InputDecoration(
                        labelText: 'Mida Cel·la Grid (m) - Def: 0.2',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    feedbackWidget,
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () {
                        final nom = nameCtrl.text;
                        final w = double.tryParse(widthCtrl.text) ?? 0;
                        final l = double.tryParse(lengthCtrl.text) ?? 5;
                        final n = int.tryParse(numBedsCtrl.text) ?? 0;
                        final p = double.tryParse(pathWidthCtrl.text) ?? 0;
                        final cSize = double.tryParse(cellSizeCtrl.text) ?? 0.2;

                        final totalPath = (n + 1) * p;
                        final totalBedSpace = w - totalPath;
                        final bedWidth = totalBedSpace / n;

                        final layoutConfig = GardenLayoutConfig(
                          totalWidth: w,
                          totalLength: l,
                          numberOfBeds: n,
                          bedWidth: bedWidth,
                          pathWidth: p,
                          cellSize: cSize,
                        );

                        final newEspai = EspaiHort(
                          id: '',
                          nom: nom,
                          center: const LatLng(0, 0), // Undefined location
                          width: w,
                          length: l,
                          gridCellSize: cSize,
                          layoutConfig: layoutConfig,
                        );

                        ref
                            .read(hortRepositoryProvider)
                            .saveEspai(newEspai)
                            .then((_) {
                              if (context.mounted) Navigator.pop(context);
                            });
                      }
                    : null,
                child: const Text('Crear Espai'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, EspaiHort espai) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Espai?'),
        content: Text('Estàs segur que vols eliminar "${espai.nom}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              ref.read(hortRepositoryProvider).deleteEspai(espai.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Sí, eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
