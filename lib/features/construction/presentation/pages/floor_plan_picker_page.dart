import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/construction_provider.dart';
import '../widgets/interactive_floor_plan.dart';

class FloorPlanPickerPage extends ConsumerWidget {
  final String floorId;
  final String? currentPointId; // To highlight or exclude content

  const FloorPlanPickerPage({
    super.key,
    required this.floorId,
    this.currentPointId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    final pointsAsync = ref.watch(constructionPointsProvider(floorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Triar nova ubicació')),
      body: floorPlansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (floorPlans) {
          final imageUrl = floorPlans[floorId];

          return pointsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
            data: (points) {
              return InteractiveFloorPlan(
                floorId: floorId,
                imageUrl: imageUrl,
                points: points, // Show all points for context
                isUploading: false,
                onPointTap: (x, y) async {
                  // Confirm dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar reubicació'),
                      content: const Text(
                        'Vols moure el punt a aquesta posició?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL·LAR'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('MOURE'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    Navigator.pop(context, {'x': x, 'y': y});
                  }
                },
                onMarkerTap: (point) {
                  // Maybe just show info?
                  if (point.id == currentPointId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Aquesta és la posició actual'),
                      ),
                    );
                  }
                },
                onUploadPlan: (file) {
                  // Disable uploading here
                },
                onDeletePlan: null, // Disable delete
              );
            },
          );
        },
      ),
    );
  }
}
