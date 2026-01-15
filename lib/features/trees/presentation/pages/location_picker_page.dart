import 'dart:math'; // Added import
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  final double? width; // Optional width in meters
  final double? height; // Optional height in meters
  final String? label; // Optional label for the area

  const LocationPickerPage({
    super.key,
    required this.initialLocation,
    this.width,
    this.height,
    this.label,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _currentLocation;
  final MapController _mapController = MapController();
  int _currentLayerIndex = 0; // 0: Ortho (Sat), 1: Topo (Map)
  bool _isLoadingLocation = false;
  List<LatLng> _polygonPoints = [];

  static const List<String> _layerUrls = [
    'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
    'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/topo/GRID3857/{z}/{x}/{y}.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _updatePolygon();
  }

  void _updatePolygon() {
    if (widget.width == null || widget.height == null) {
      _polygonPoints = [];
      return;
    }

    final halfW = widget.width! / 2;
    final halfH = widget.height! / 2;

    // Approximation for meters to degrees
    const metersPerDegLat = 111132.95;
    final metersPerDegLng =
        111132.95 * cos(_currentLocation.latitude * pi / 180);

    final latDelta = halfH / metersPerDegLat;
    final lngDelta = halfW / metersPerDegLng;

    setState(() {
      _polygonPoints = [
        LatLng(
          _currentLocation.latitude + latDelta,
          _currentLocation.longitude - lngDelta,
        ), // TL
        LatLng(
          _currentLocation.latitude + latDelta,
          _currentLocation.longitude + lngDelta,
        ), // TR
        LatLng(
          _currentLocation.latitude - latDelta,
          _currentLocation.longitude + lngDelta,
        ), // BR
        LatLng(
          _currentLocation.latitude - latDelta,
          _currentLocation.longitude - lngDelta,
        ), // BL
      ];
    });
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();
      final newLoc = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = newLoc);
      _updatePolygon();
      _mapController.move(newLoc, 18);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error GPS: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moure el marcador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _currentLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 19,
              onTap: (_, point) {
                setState(() {
                  _currentLocation = point;
                  _updatePolygon();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _layerUrls[_currentLayerIndex],
                userAgentPackageName: 'com.soca.app',
                maxZoom: 20,
              ),
              if (_polygonPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: Colors.green.withValues(alpha: 0.3),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                      label: widget.label,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_polygonPoints.isEmpty)
                    Marker(
                      point: _currentLocation,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Controls
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'layer_switch',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _currentLayerIndex =
                          (_currentLayerIndex + 1) % _layerUrls.length;
                    });
                  },
                  child: Icon(
                    _currentLayerIndex == 0 ? Icons.map : Icons.satellite,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'my_location',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _isLoadingLocation ? null : _moveToCurrentLocation,
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: Colors.blue),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _currentLocation),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('CONFIRMAR POSICIÓ'),
            ),
          ),
        ],
      ),
    );
  }
}
