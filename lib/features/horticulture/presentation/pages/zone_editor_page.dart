import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/settings/presentation/providers/settings_provider.dart';
import '../../../../features/map/presentation/providers/map_layers_provider.dart';

class ZoneEditorPage extends ConsumerStatefulWidget {
  const ZoneEditorPage({super.key});

  @override
  ConsumerState<ZoneEditorPage> createState() => _ZoneEditorPageState();
}

class _ZoneEditorPageState extends ConsumerState<ZoneEditorPage> {
  final MapController _mapController = MapController();

  // Example zone: 10m x 6m roughly in lat/long (placeholder coords)
  // Center roughly at 41.512500, 0.918800 from existing code
  final List<LatLng> _demoZonePoints = [
    LatLng(41.512800, 0.918400),
    LatLng(41.512800, 0.918800),
    LatLng(41.512500, 0.918800),
    LatLng(41.512500, 0.918400),
  ];

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(farmConfigStreamProvider);
    final layers = ref.watch(mapLayersProvider);

    return configAsync.when(
      data: (config) {
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(config.latitude, config.longitude),
                initialZoom: 19.0, // Zoomed in for detailed zone editing
                maxZoom: 22.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: (layers[MapLayer.useOpenStreetMap] ?? false)
                      ? ((layers[MapLayer.satellite] ?? false)
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png')
                      : ((layers[MapLayer.satellite] ?? false)
                            ? 'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg'
                            : 'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/topo/GRID3857/{z}/{x}/{y}.jpeg'),
                  userAgentPackageName: 'com.molicaljeroni.soca',
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _demoZonePoints,
                      color: Colors.green.withValues(alpha: 0.3),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                      label: 'Zona Horta 1',
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edició de zones properament'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
