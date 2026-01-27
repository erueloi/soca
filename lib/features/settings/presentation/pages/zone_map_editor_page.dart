import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../domain/entities/farm_config.dart';

class ZoneMapEditorPage extends StatefulWidget {
  final PermacultureZone? zone;
  final LatLng initialCenter;
  final double initialZoom;

  const ZoneMapEditorPage({
    super.key,
    this.zone,
    required this.initialCenter,
    required this.initialZoom,
  });

  @override
  State<ZoneMapEditorPage> createState() => _ZoneMapEditorPageState();
}

class _ZoneMapEditorPageState extends State<ZoneMapEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late Color _color;

  final MapController _mapController = MapController();
  List<LatLng> _polygonPoints = [];
  final bool _isDrawing = true; // Mode drawing vs viewing

  // Predefined PDC colors
  final List<Color> _pdcColors = [
    const Color(0xFFE57373), // Zone 0 - Red/Pink (Home)
    const Color(0xFFFFB74D), // Zone 1 - Orange (Kitchen Garden)
    const Color(0xFFFFD54F), // Zone 2 - Yellow (Orchard/Poultry)
    const Color(0xFF81C784), // Zone 3 - Green (Crops/Grazing)
    const Color(0xFF4DB6AC), // Zone 4 - Teal (Forest/Woods)
    const Color(0xFF90A4AE), // Zone 5 - Blue Grey (Wilderness)
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.zone?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.zone?.descriptionPdc ?? '',
    );
    _color = widget.zone != null
        ? Color(int.parse(widget.zone!.colorHex, radix: 16))
        : _pdcColors[0];

    if (widget.zone != null) {
      _polygonPoints = widget.zone!.polygon
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    if (!_isDrawing) return;
    setState(() {
      _polygonPoints.add(point);
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _polygonPoints.clear();
    });
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tria un color PDC'),
        content: BlockPicker(
          pickerColor: _color,
          availableColors:
              _pdcColors +
              [Colors.purple, Colors.indigo, Colors.blue, Colors.brown],
          onColorChanged: (color) {
            setState(() => _color = color);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Defineix almenys 3 punts per crear una zona.'),
        ),
      );
      return;
    }

    final zone = PermacultureZone(
      id: widget.zone?.id ?? const Uuid().v4(),
      name: _nameController.text,
      colorHex: _color.toARGB32().toRadixString(16).padLeft(8, '0'),
      descriptionPdc: _descriptionController.text,
      polygon: _polygonPoints
          .map((p) => GeoPoint(p.latitude, p.longitude))
          .toList(),
    );

    Navigator.pop(context, zone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zone == null ? 'Nova Zona PDC' : 'Editar Zona PDC'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3, // Map takes 60% approx
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _polygonPoints.isNotEmpty
                        ? _polygonPoints.first
                        : widget.initialCenter,
                    initialZoom: widget.initialZoom,
                    onTap: _handleTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
                      userAgentPackageName: 'com.soca.app',
                    ),
                    if (_polygonPoints.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            color: _color.withValues(alpha: 0.4),
                            borderStrokeWidth: 2,
                            borderColor: _color,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _polygonPoints
                          .map(
                            (p) => Marker(
                              point: p,
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'undo',
                        onPressed: _polygonPoints.isEmpty
                            ? null
                            : _undoLastPoint,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.undo, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'clear',
                        onPressed: _polygonPoints.isEmpty ? null : _clearPoints,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Toca al mapa per afegir punts del polígon',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2, // Form takes 40%
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickColor,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom de la Zona (ex: Zona 1)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Requerit' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripció PDC',
                        hintText:
                            'Defineix objectius, elements i estratègies...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
