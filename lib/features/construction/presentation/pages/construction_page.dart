import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/construction_provider.dart';
import '../../data/models/construction_point.dart';
import '../widgets/interactive_floor_plan.dart';
import '../widgets/pathology_sheet_modal.dart';

class ConstructionPage extends ConsumerStatefulWidget {
  const ConstructionPage({super.key});

  @override
  ConsumerState<ConstructionPage> createState() => _ConstructionPageState();
}

class _ConstructionPageState extends ConsumerState<ConstructionPage> {
  // Hardcoded floors for now, could be dynamic
  final List<String> _floors = [
    'Planta Baixa',
    'Planta 1',
    'Planta 2',
    'Coberta',
  ];

  // Track expanded state locally
  final Map<String, bool> _expanded = {
    'Planta Baixa': true, // Default open first
    'Planta 1': false,
    'Planta 2': false,
    'Coberta': false,
  };

  // Track upload state per floor to show spinner
  final Map<String, bool> _uploading = {};

  @override
  Widget build(BuildContext context) {
    // Watch floor plans to get URLs
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Obres de la Masia')),
      body: floorPlansAsync.when(
        data: (floorPlans) {
          return SingleChildScrollView(
            child: ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  _expanded[_floors[index]] = isExpanded;
                });
              },
              children: _floors.map<ExpansionPanel>((String floor) {
                return ExpansionPanel(
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      title: Text(
                        floor,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      leading: const Icon(Icons.layers_outlined),
                    );
                  },
                  body: _buildFloorBody(floor, floorPlans[floor]),
                  isExpanded: _expanded[floor] ?? false,
                  canTapOnHeader: true, // Allow tapping anywhere on header
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildFloorBody(String floorId, String? imageUrl) {
    // Watch points for this floor
    final pointsAsync = ref.watch(constructionPointsProvider(floorId));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: pointsAsync.when(
        data: (points) {
          return InteractiveFloorPlan(
            floorId: floorId,
            imageUrl: imageUrl,
            points: points,
            isUploading: _uploading[floorId] ?? false,
            onPointTap: (xPercent, yPercent) {
              _createNewPoint(floorId, xPercent, yPercent);
            },
            onMarkerTap: (point) {
              _openPathologySheet(point);
            },
            onUploadPlan: (file) async {
              setState(() => _uploading[floorId] = true);
              try {
                await ref
                    .read(constructionRepositoryProvider)
                    .saveFloorPlan(floorId, file);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              } finally {
                if (mounted) setState(() => _uploading[floorId] = false);
              }
            },
            onDeletePlan: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar Plànol?'),
                  content: const Text(
                    'Estàs segur que vols eliminar aquest plànol? Els punts creats es mantindran però sense fons.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL·LAR'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ELIMINAR'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() => _uploading[floorId] = true);
                try {
                  await ref
                      .read(constructionRepositoryProvider)
                      .deleteFloorPlan(floorId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _uploading[floorId] = false);
                }
              }
            },
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, s) => Text('Error loading points: $e'),
      ),
    );
  }

  void _createNewPoint(String floorId, double x, double y) {
    // Create a temporary point or just open modal with preset "New" data
    final newPoint = ConstructionPoint(
      id: const Uuid().v4(), // Generate ID
      floorId: floorId,
      xPercent: x,
      yPercent: y,
      createdAt: DateTime.now(),
      status: 'Pendent',
      // Pathology is null initially
    );

    _openPathologySheet(newPoint, isNew: true);
  }

  void _openPathologySheet(ConstructionPoint point, {bool isNew = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PathologySheetModal(
        point: point,
        onSave: (updatedPoint) async {
          final repo = ref.read(constructionRepositoryProvider);
          if (isNew) {
            await repo.addPoint(updatedPoint);
          } else {
            await repo.updatePoint(updatedPoint);
          }
        },
      ),
    );
  }
}
