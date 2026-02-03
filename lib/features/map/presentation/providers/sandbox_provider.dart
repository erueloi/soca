import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_layers_provider.dart';

class SandboxNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false; // Default: Sandbox Mode OFF
  }

  void toggle() {
    state = !state;

    // Auto-toggle 'Future Projects' layer based on Sandbox Mode
    final layersNotifier = ref.read(mapLayersProvider.notifier);
    layersNotifier.setLayer(MapLayer.futureProjects, state);
  }
}

final sandboxProvider = NotifierProvider<SandboxNotifier, bool>(
  SandboxNotifier.new,
);
