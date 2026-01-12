import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/construction_point.dart';

class InteractiveFloorPlan extends StatefulWidget {
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
    this.isReadOnly = false,
  });

  final bool isReadOnly;

  @override
  State<InteractiveFloorPlan> createState() => _InteractiveFloorPlanState();
}

class _InteractiveFloorPlanState extends State<InteractiveFloorPlan> {
  String? _selectedPointId;
  final TransformationController _transformationController =
      TransformationController();
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(InteractiveFloorPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resolveImage() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() => _aspectRatio = null);
      return;
    }

    final ImageStream stream = NetworkImage(
      widget.imageUrl!,
    ).resolve(ImageConfiguration.empty);

    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _aspectRatio = info.image.width / info.image.height;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
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
                'No hi ha plànol per ${widget.floorId}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (!widget.isReadOnly) _buildUploadButton(context),
            ],
          ),
        ),
      );
    }

    if (_aspectRatio == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(
                  100,
                ), // Allow some panning outside
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _aspectRatio!,
                    child: LayoutBuilder(
                      builder: (context, boxConstraints) {
                        return GestureDetector(
                          onTapUp: (details) {
                            if (widget.isReadOnly) {
                              return;
                            }
                            if (_selectedPointId != null) {
                              setState(() => _selectedPointId = null);
                              return;
                            }

                            final RenderBox box =
                                context.findRenderObject() as RenderBox;
                            final localPosition = box.globalToLocal(
                              details.globalPosition,
                            );

                            final xPercent = localPosition.dx / box.size.width;
                            final yPercent = localPosition.dy / box.size.height;

                            widget.onPointTap(xPercent, yPercent);
                          },
                          child: Stack(
                            children: [
                              // Image
                              Positioned.fill(
                                child: Image.network(
                                  widget.imageUrl!,
                                  fit: BoxFit.fill,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text("Error carregant imatge"),
                                    );
                                  },
                                ),
                              ),

                              // Markers
                              ...widget.points.map((point) {
                                return Positioned(
                                  left:
                                      boxConstraints.maxWidth * point.xPercent,
                                  top:
                                      boxConstraints.maxHeight * point.yPercent,
                                  child: FractionalTranslation(
                                    translation: const Offset(-0.5, -0.5),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedPointId = point.id,
                                        );
                                      },
                                      child: _buildMarkerCircle(point),
                                    ),
                                  ),
                                );
                              }),

                              // Tooltip
                              if (_selectedPointId != null)
                                _buildTooltip(context, boxConstraints),

                              if (widget.isUploading)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (!widget.isReadOnly)
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
                      widget.onUploadPlan(file);
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Canviar Plànol"),
                ),
                if (widget.onDeletePlan != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onDeletePlan,
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
    if (widget.isUploading) {
      return const CircularProgressIndicator();
    }

    return ElevatedButton.icon(
      onPressed: () async {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          widget.onUploadPlan(file);
        }
      },
      icon: const Icon(Icons.upload_file),
      label: const Text('Pujar Plànol'),
    );
  }

  Widget _buildMarkerCircle(ConstructionPoint point) {
    Color color = Colors.green;
    final severity = point.pathology?.severity ?? 0;

    if (severity >= 8) {
      color = Colors.red;
    } else if (severity >= 4) {
      color = Colors.yellow.shade700;
    } else {
      color = Colors.green;
    }

    final isSelected = _selectedPointId == point.id;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: isSelected
          ? const Center(
              child: Icon(Icons.close, size: 14, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTooltip(BuildContext context, BoxConstraints constraints) {
    final point = widget.points.firstWhere((p) => p.id == _selectedPointId);
    final severity = point.pathology?.severity ?? 0;
    Color color = Colors.green;
    if (severity >= 8) {
      color = Colors.red;
    } else if (severity >= 4) {
      color = Colors.yellow.shade700;
    }

    // Calculate position to ensure it stays on screen
    double left =
        constraints.maxWidth * point.xPercent - 100; // Center horiz approx
    double top = constraints.maxHeight * point.yPercent - 100; // Above marker

    // Clamp
    if (left < 10) left = 10;
    if (left + 200 > constraints.maxWidth) left = constraints.maxWidth - 210;
    if (top < 10) {
      top =
          constraints.maxHeight * point.yPercent +
          30; // Move below if too close to top
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point.pathology?.title ?? 'Sense Títol',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (point.pathology?.photoUrls.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      point.pathology!.photoUrls.first,
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade900,
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Open Detail Page
                    widget.onMarkerTap(point);
                    setState(() => _selectedPointId = null);
                  },
                  child: const Text('Més detalls'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
