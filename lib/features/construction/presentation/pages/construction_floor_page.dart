import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/construction_provider.dart';
import '../../data/models/construction_point.dart';
import '../widgets/interactive_floor_plan.dart';
import '../widgets/pathology_sheet_modal.dart';
import 'pathology_detail_page.dart';

class ConstructionFloorPage extends ConsumerStatefulWidget {
  final String floorId;

  const ConstructionFloorPage({super.key, required this.floorId});

  @override
  ConsumerState<ConstructionFloorPage> createState() =>
      _ConstructionFloorPageState();
}

class _ConstructionFloorPageState extends ConsumerState<ConstructionFloorPage> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    // Watch floor plans to get URL for this floor
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    // Watch points for this floor
    final pointsAsync = ref.watch(constructionPointsProvider(widget.floorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorId),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: floorPlansAsync.when(
        data: (floorPlans) {
          final imageUrl = floorPlans[widget.floorId];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: pointsAsync.when(
              data: (points) {
                return InteractiveFloorPlan(
                  floorId: widget.floorId,
                  imageUrl: imageUrl,
                  points: points,
                  isUploading: _isUploading,
                  onPointTap: (xPercent, yPercent) {
                    _createNewPoint(widget.floorId, xPercent, yPercent);
                  },
                  onMarkerTap: (point) {
                    final index = points.indexOf(point);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PathologyCarouselPage(
                          points: points,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  onUploadPlan: (file) async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    setState(() => _isUploading = true);
                    try {
                      await ref
                          .read(constructionRepositoryProvider)
                          .saveFloorPlan(widget.floorId, file);
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isUploading = false);
                    }
                  },
                  onDeletePlan: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ELIMINAR'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      setState(() => _isUploading = true);
                      try {
                        await ref
                            .read(constructionRepositoryProvider)
                            .deleteFloorPlan(widget.floorId);
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUploading = false);
                      }
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading points: $e')),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _createNewPoint(String floorId, double x, double y) {
    final newPoint = ConstructionPoint(
      id: const Uuid().v4(),
      floorId: floorId,
      xPercent: x,
      yPercent: y,
      createdAt: DateTime.now(),
      status: 'Pendent',
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
