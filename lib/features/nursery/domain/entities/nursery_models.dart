import 'package:cloud_firestore/cloud_firestore.dart';

// --- Enums ---

enum TrayStatus {
  germination,
  growing,
  hardening,
  ready,
  archived;

  String get label {
    switch (this) {
      case TrayStatus.germination:
        return 'Germinació';
      case TrayStatus.growing:
        return 'Creixement';
      case TrayStatus.hardening:
        return 'Enduriment';
      case TrayStatus.ready:
        return 'Llesta';
      case TrayStatus.archived:
        return 'Arxivada';
    }
  }
}

// --- TrayItem ---

class TrayItem {
  final String speciesId;
  final String speciesName;
  final int quantity;
  final int? germinatedCount;
  final int diesGerminacio;
  final int diesPlanter;

  const TrayItem({
    required this.speciesId,
    this.speciesName = '',
    required this.quantity,
    this.germinatedCount,
    this.diesGerminacio = 8,
    this.diesPlanter = 45,
  });

  TrayItem copyWith({
    String? speciesId,
    String? speciesName,
    int? quantity,
    int? germinatedCount,
    int? diesGerminacio,
    int? diesPlanter,
  }) {
    return TrayItem(
      speciesId: speciesId ?? this.speciesId,
      speciesName: speciesName ?? this.speciesName,
      quantity: quantity ?? this.quantity,
      germinatedCount: germinatedCount ?? this.germinatedCount,
      diesGerminacio: diesGerminacio ?? this.diesGerminacio,
      diesPlanter: diesPlanter ?? this.diesPlanter,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'speciesId': speciesId,
      'speciesName': speciesName,
      'quantity': quantity,
      'germinatedCount': germinatedCount,
      'diesGerminacio': diesGerminacio,
      'diesPlanter': diesPlanter,
    };
  }

  factory TrayItem.fromMap(Map<String, dynamic> map) {
    return TrayItem(
      speciesId: map['speciesId'] ?? '',
      speciesName: map['speciesName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      germinatedCount: (map['germinatedCount'] as num?)?.toInt(),
      diesGerminacio: (map['diesGerminacio'] as num?)?.toInt() ?? 8,
      diesPlanter: (map['diesPlanter'] as num?)?.toInt() ?? 45,
    );
  }
}

// --- SeedTray ---

class SeedTray {
  final String id;
  final String fincaId;
  final String name;
  final TrayStatus status;
  final DateTime plantedAt;
  final DateTime? expectedTransplantDate;
  final List<TrayItem> items;

  const SeedTray({
    required this.id,
    required this.fincaId,
    required this.name,
    required this.status,
    required this.plantedAt,
    this.expectedTransplantDate,
    this.items = const [],
  });

  SeedTray copyWith({
    String? id,
    String? fincaId,
    String? name,
    TrayStatus? status,
    DateTime? plantedAt,
    DateTime? expectedTransplantDate,
    List<TrayItem>? items,
  }) {
    return SeedTray(
      id: id ?? this.id,
      fincaId: fincaId ?? this.fincaId,
      name: name ?? this.name,
      status: status ?? this.status,
      plantedAt: plantedAt ?? this.plantedAt,
      expectedTransplantDate:
          expectedTransplantDate ?? this.expectedTransplantDate,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fincaId': fincaId,
      'name': name,
      'status': status.name,
      'plantedAt': Timestamp.fromDate(plantedAt),
      'expectedTransplantDate': expectedTransplantDate != null
          ? Timestamp.fromDate(expectedTransplantDate!)
          : null,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory SeedTray.fromMap(Map<String, dynamic> map, String id) {
    return SeedTray(
      id: id,
      fincaId: map['fincaId'] ?? '',
      name: map['name'] ?? '',
      status: TrayStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TrayStatus.germination,
      ),
      plantedAt: _parseDate(map['plantedAt']) ?? DateTime.now(),
      expectedTransplantDate: _parseDate(map['expectedTransplantDate']),
      items: map['items'] != null
          ? (map['items'] as List<dynamic>)
                .map((e) => TrayItem.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}

extension SeedTrayX on SeedTray {
  /// Returns the maximum germination days among all items in the tray.
  int get estimatedGerminationDays {
    if (items.isEmpty) return 8; // Default if empty
    return items.map((i) => i.diesGerminacio).reduce((a, b) => a > b ? a : b);
  }

  /// Returns the maximum transplant days among all items in the tray.
  int get estimatedTransplantDays {
    if (items.isEmpty) return 45; // Default if empty
    return items.map((i) => i.diesPlanter).reduce((a, b) => a > b ? a : b);
  }
}

// --- Helpers ---

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
