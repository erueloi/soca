class SpeciesConfig {
  static const Map<String, double> defaultKc = {
    'Olivera': 0.6,
    'Noguer': 1.0,
    'Hort': 0.8,
    'Vinya': 0.7,
    'Ametller': 0.9,
    'Fruiters': 1.0,
    'Gespa': 1.0,
  };

  static const double unknownKc = 0.5;

  static double getKc(String speciesName) {
    // Basic fuzzy matching
    final key = defaultKc.keys.firstWhere(
      (k) => speciesName.toLowerCase().contains(k.toLowerCase()),
      orElse: () => '',
    );

    if (key.isNotEmpty) return defaultKc[key]!;

    return unknownKc;
  }
}
