import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapLayer { tasks, irrigationZones, healthStatus }

class MapLayersNotifier extends Notifier<Map<MapLayer, bool>> {
  @override
  Map<MapLayer, bool> build() {
    _loadPreferences();
    return {
      MapLayer.tasks: true,
      MapLayer.irrigationZones: false,
      MapLayer.healthStatus: false,
    };
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = {
        MapLayer.tasks: prefs.getBool('layer_tasks') ?? true,
        MapLayer.irrigationZones:
            prefs.getBool('layer_irrigationZones') ?? false,
        MapLayer.healthStatus: prefs.getBool('layer_healthStatus') ?? false,
      };
    } catch (e) {
      // Gracefully handle missing plugin or other errors
      // Gracefully handle missing plugin or other errors
      // print('Error loading map preferences: $e'); // Disabled for production rules
    }
  }

  Future<void> toggleLayer(MapLayer layer) async {
    final newState = {...state, layer: !state[layer]!};
    state = newState;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('layer_${layer.name}', newState[layer]!);
  }
}

final mapLayersProvider =
    NotifierProvider<MapLayersNotifier, Map<MapLayer, bool>>(() {
      return MapLayersNotifier();
    });
