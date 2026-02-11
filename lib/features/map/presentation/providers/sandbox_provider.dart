import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_layers_provider.dart';

class SandboxState {
  final bool isEnabled;
  final double years; // 0 = Planting, up to e.g. 30 = Adult

  const SandboxState({
    this.isEnabled = false,
    this.years = 5.0, // Default start at 5 years
  });

  SandboxState copyWith({bool? isEnabled, double? years}) {
    return SandboxState(
      isEnabled: isEnabled ?? this.isEnabled,
      years: years ?? this.years,
    );
  }
}

class SandboxNotifier extends Notifier<SandboxState> {
  @override
  SandboxState build() {
    return const SandboxState();
  }

  void toggle() {
    state = state.copyWith(isEnabled: !state.isEnabled);

    // Auto-toggle 'Provisional Trees' layer based on Sandbox Mode
    final layersNotifier = ref.read(mapLayersProvider.notifier);
    layersNotifier.setLayer(MapLayer.provisionalTrees, state.isEnabled);
  }

  void setYears(double years) {
    state = state.copyWith(years: years);
  }
}

final sandboxProvider = NotifierProvider<SandboxNotifier, SandboxState>(
  SandboxNotifier.new,
);
