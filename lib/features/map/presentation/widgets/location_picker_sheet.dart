import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerSheet extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerSheet({super.key, this.initialLocation});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late LatLng _currentLocation;
  // Default to Molí de Cal Jeroni approximate location if none provided
  // Default to Molí de Cal Jeroni
  static const LatLng _defaultCenter = LatLng(41.5126017, 0.9185921);

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triar Ubicació'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _currentLocation);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 18.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _currentLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
                userAgentPackageName: 'com.soca.app',
                maxZoom: 20,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Toca al mapa per moure el marcador\nLat: ${_currentLocation.latitude.toStringAsFixed(5)}, Lng: ${_currentLocation.longitude.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
