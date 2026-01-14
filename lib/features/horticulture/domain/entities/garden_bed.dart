class GardenBed {
  final String id;
  final String zoneId;
  final String name;
  final int widthCells; // Number of cells horizontally
  final int heightCells; // Number of cells vertically
  final Map<String, String> cells; // Key: "x_y", Value: plantId (or speciesId)

  GardenBed({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.widthCells,
    required this.heightCells,
    required this.cells,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zoneId': zoneId,
      'name': name,
      'widthCells': widthCells,
      'heightCells': heightCells,
      'cells': cells,
    };
  }

  factory GardenBed.fromMap(Map<String, dynamic> map, String documentId) {
    return GardenBed(
      id: documentId,
      zoneId: map['zoneId'] ?? '',
      name: map['name'] ?? '',
      widthCells: map['widthCells'] ?? 10,
      heightCells: map['heightCells'] ?? 6,
      cells: Map<String, String>.from(map['cells'] ?? {}),
    );
  }
}
