import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/construction_point.dart';

class InteractiveFloorPlan extends StatelessWidget {
  final String floorId;
  final String? imageUrl;
  final List<ConstructionPoint> points;
  final Function(double xPercent, double yPercent) onPointTap;
  final Function(ConstructionPoint) onMarkerTap;
  final Function(XFile) onUploadPlan;
  final VoidCallback? onDeletePlan;
  final bool isUploading;

  const InteractiveFloorPlan({
    super.key,
    required this.floorId,
    required this.imageUrl,
    required this.points,
    required this.onPointTap,
    required this.onMarkerTap,
    required this.onUploadPlan,
    this.onDeletePlan,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No hi ha plànol per $floorId',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _buildUploadButton(context),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(
                      details.globalPosition,
                    );

                    final xPercent = localPosition.dx / box.size.width;
                    final yPercent = localPosition.dy / box.size.height;

                    onPointTap(xPercent, yPercent);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Text("Error carregant imatge"),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ...points.map((point) {
              // Convert % to position. We use Alignment to be container-size independent more easily in Stack.
              // Actually, in a Stack with an Image, it's tricky if the image doesn't fill the space.
              // Better use a LayoutBuilder wrapping the Stack or ensure the image defines the size.
              // For robustness, 'Align' with fractional offset is good.

              // Note: FractionalOffset (0,0) is top-left, (1,1) is bottom-right.
              return Positioned.fill(
                child: Align(
                  alignment: FractionalOffset(point.xPercent, point.yPercent),
                  child: GestureDetector(
                    onTap: () => onMarkerTap(point),
                    child: _buildMarker(point),
                  ),
                ),
              );
            }),
            if (isUploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file != null) {
                    onUploadPlan(file);
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("Canviar Plànol"),
              ),
              if (onDeletePlan != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDeletePlan,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Eliminar",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(BuildContext context) {
    if (isUploading) return const CircularProgressIndicator();

    return ElevatedButton.icon(
      onPressed: () async {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          onUploadPlan(file);
        }
      },
      icon: const Icon(Icons.upload_file),
      label: const Text('Pujar Plànol'),
    );
  }

  Widget _buildMarker(ConstructionPoint point) {
    Color color = Colors.red;
    if (point.pathology != null) {
      switch (point.pathology!.severity) {
        case int s when s <= 3:
          color = Colors.green;
          break;
        case int s when s <= 6:
          color = Colors.orange;
          break;
        case int s when s > 6:
          color = Colors.red;
          break;
      }
    }

    // Calculate tooltip size or transform alignment to center the pin tip on the coordinate
    // The Align places the CENTER of the child at the fractional offset.
    // If we want the pin TIP at the coordinate, we need to offset it up.
    // Transform.translate can handle this.

    return Transform.translate(
      offset: const Offset(0, -15), // Shift up by half height approx
      child: Icon(
        Icons.location_on,
        color: color,
        size: 30,
        shadows: const [
          Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
