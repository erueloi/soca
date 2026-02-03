import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TreeFilterState {
  final Set<String> hiddenStatuses; // Blacklist logic (e.g. contains 'Planned')
  final Set<String> selectedSpecies; // Whitelist logic (empty = all)
  final Set<String> selectedZones; // Whitelist logic (empty = all)

  const TreeFilterState({
    this.hiddenStatuses = const {},
    this.selectedSpecies = const {},
    this.selectedZones = const {},
  });

  TreeFilterState copyWith({
    Set<String>? hiddenStatuses,
    Set<String>? selectedSpecies,
    Set<String>? selectedZones,
  }) {
    return TreeFilterState(
      hiddenStatuses: hiddenStatuses ?? this.hiddenStatuses,
      selectedSpecies: selectedSpecies ?? this.selectedSpecies,
      selectedZones: selectedZones ?? this.selectedZones,
    );
  }
}

class TreeFilterNotifier extends Notifier<TreeFilterState> {
  static const _kHiddenStatusesKey = 'tree_filter_hidden_statuses';
  static const _kSelectedSpeciesKey = 'tree_filter_selected_species';
  static const _kSelectedZonesKey = 'tree_filter_selected_zones';

  @override
  TreeFilterState build() {
    _loadPreferences();
    // Default initial state: Hide 'Planned' and 'Planificat'
    return const TreeFilterState(hiddenStatuses: {'Planned', 'Planificat'});
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_kHiddenStatusesKey)?.toSet();
      final species = prefs.getStringList(_kSelectedSpeciesKey)?.toSet();
      final zones = prefs.getStringList(_kSelectedZonesKey)?.toSet();

      if (hidden != null || species != null || zones != null) {
        state = state.copyWith(
          hiddenStatuses:
              hidden, // If null, keeps default from build() or current
          selectedSpecies: species,
          selectedZones: zones,
        );
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kHiddenStatusesKey,
      state.hiddenStatuses.toList(),
    );
    await prefs.setStringList(
      _kSelectedSpeciesKey,
      state.selectedSpecies.toList(),
    );
    await prefs.setStringList(_kSelectedZonesKey, state.selectedZones.toList());
  }

  void toggleStatusVisibility(String status) {
    // Logic: If in hidden set -> Remove it (Make visible).
    // If not in hidden set -> Add it (Hide it).
    final newHidden = Set<String>.from(state.hiddenStatuses);
    if (newHidden.contains(status)) {
      newHidden.remove(status);
    } else {
      newHidden.add(status);
    }
    state = state.copyWith(hiddenStatuses: newHidden);
    _savePreferences();
  }

  void toggleSpecies(String species) {
    final newSelected = Set<String>.from(state.selectedSpecies);
    if (newSelected.contains(species)) {
      newSelected.remove(species);
    } else {
      newSelected.add(species);
    }
    state = state.copyWith(selectedSpecies: newSelected);
    _savePreferences();
  }

  void toggleZone(String zoneId) {
    final newSelected = Set<String>.from(state.selectedZones);
    if (newSelected.contains(zoneId)) {
      newSelected.remove(zoneId);
    } else {
      newSelected.add(zoneId);
    }
    state = state.copyWith(selectedZones: newSelected);
    _savePreferences();
  }

  void clearFilters() {
    // Reset to defaults: Only Planned hidden
    state = const TreeFilterState(
      hiddenStatuses: {'Planned', 'Planificat'},
      selectedSpecies: {},
      selectedZones: {},
    );
    _savePreferences();
  }
}

final treeFilterProvider =
    NotifierProvider<TreeFilterNotifier, TreeFilterState>(
      TreeFilterNotifier.new,
    );
