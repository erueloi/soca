class GardenLayoutConfig {
  final double totalWidth; // meters (X axis)
  final double totalLength; // meters (Y axis)
  final int numberOfBeds;
  final double bedWidth; // meters
  final double pathWidth; // meters
  // final double orientation; // Degrees, future use

  const GardenLayoutConfig({
    required this.totalWidth,
    required this.totalLength,
    required this.numberOfBeds,
    required this.bedWidth,
    required this.pathWidth,
    this.cellSize = 0.20,
  });

  final double cellSize; // meters (grid resolution)

  // Helper to validate if beds fit in width
  bool get isValid {
    double requiredWidth =
        (numberOfBeds * bedWidth) + ((numberOfBeds - 1) * pathWidth);
    return requiredWidth <= totalWidth;
  }
}
