import 'package:flutter_riverpod/flutter_riverpod.dart';

class HiddenSpeciesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  void toggle(String species) {
    if (state.contains(species)) {
      state = {...state}..remove(species);
    } else {
      state = {...state, species};
    }
  }

  void showAll() {
    state = {};
  }

  void hideAll(List<String> allSpecies) {
    state = Set.from(allSpecies);
  }
}

final hiddenSpeciesProvider =
    NotifierProvider<HiddenSpeciesNotifier, Set<String>>(() {
      return HiddenSpeciesNotifier();
    });
