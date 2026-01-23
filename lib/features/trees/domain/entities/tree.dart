import 'package:cloud_firestore/cloud_firestore.dart';

class TreeEvent {
  final DateTime date;
  final String? photoUrl;
  final String note;

  const TreeEvent({required this.date, this.photoUrl, required this.note});

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'photoUrl': photoUrl,
      'note': note,
    };
  }

  factory TreeEvent.fromMap(Map<String, dynamic> map) {
    return TreeEvent(
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: map['photoUrl'],
      note: map['note'] ?? '',
    );
  }
}

class Tree {
  final String id;
  final String species;
  final String commonName;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final DateTime plantingDate;
  final String status; // 'Viable', 'Mort', 'Malalt', etc.
  final String notes;
  final String? fincaId;

  // New Fields
  final String? ecologicalFunction; // Nitrogenadora, Fusta, Fruit...
  final String? plantingFormat; // Alvèol forestal, Arrel nua...
  final String? provider; // Nursery name
  final double? price;
  final String? padrino; // Responsible
  final String? maintenanceTips; // AI or Manual
  final String? vigor; // Alt, Mitjà, Baix
  final double? kc; // Crop Coefficient (coeficient_kc)
  final String? speciesId; // Link to Species Library
  final String? reference; // e.g. OLI-001
  final List<TreeEvent> timeline;

  // Age logic
  final bool isVeteran;
  final double initialAge; // Years (e.g. 0.5, 2.0)

  // Growth Logic
  final double? height; // cm
  final double? trunkDiameter; // cm

  // Water Balance Fields
  final double? soilBalance;
  final double? calculatedRegArea;
  final DateTime? lastBalanceUpdate;

  const Tree({
    required this.id,
    required this.species,
    required this.commonName,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.plantingDate,
    required this.status,
    this.notes = '',
    this.fincaId,
    this.ecologicalFunction,
    this.plantingFormat,
    this.provider,
    this.price,
    this.padrino,
    this.maintenanceTips,
    this.vigor,
    this.kc,
    this.speciesId,
    this.reference,
    this.timeline = const [],
    this.isVeteran = false,
    this.initialAge = 0.0,
    this.height,
    this.trunkDiameter,
    this.soilBalance,
    this.calculatedRegArea,
    this.lastBalanceUpdate,
  });

  Tree copyWith({
    String? species,
    String? commonName,
    String? photoUrl,
    double? latitude,
    double? longitude,
    DateTime? plantingDate,
    String? status,
    String? notes,
    String? fincaId,
    String? ecologicalFunction,
    String? plantingFormat,
    String? provider,
    double? price,
    String? padrino,
    String? maintenanceTips,
    String? vigor,
    double? kc,
    String? speciesId,
    String? reference,
    List<TreeEvent>? timeline,
    bool? isVeteran,
    double? initialAge,
    double? height,
    double? trunkDiameter,
    double? soilBalance,
    double? calculatedRegArea,
    DateTime? lastBalanceUpdate,
  }) {
    return Tree(
      id: id,
      species: species ?? this.species,
      commonName: commonName ?? this.commonName,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      plantingDate: plantingDate ?? this.plantingDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      fincaId: fincaId ?? this.fincaId,
      ecologicalFunction: ecologicalFunction ?? this.ecologicalFunction,
      plantingFormat: plantingFormat ?? this.plantingFormat,
      provider: provider ?? this.provider,
      price: price ?? this.price,
      padrino: padrino ?? this.padrino,
      maintenanceTips: maintenanceTips ?? this.maintenanceTips,
      vigor: vigor ?? this.vigor,
      kc: kc ?? this.kc,
      speciesId: speciesId ?? this.speciesId,
      reference: reference ?? this.reference,
      timeline: timeline ?? this.timeline,
      isVeteran: isVeteran ?? this.isVeteran,
      initialAge: initialAge ?? this.initialAge,
      height: height ?? this.height,
      trunkDiameter: trunkDiameter ?? this.trunkDiameter,
      soilBalance: soilBalance ?? this.soilBalance,
      calculatedRegArea: calculatedRegArea ?? this.calculatedRegArea,
      lastBalanceUpdate: lastBalanceUpdate ?? this.lastBalanceUpdate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'species': species,
      'commonName': commonName,
      'photoUrl': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'plantingDate': Timestamp.fromDate(plantingDate),
      'status': status,
      'notes': notes,
      'fincaId': fincaId,
      'ecologicalFunction': ecologicalFunction,
      'plantingFormat': plantingFormat,
      'provider': provider,
      'price': price,
      'padrino': padrino,
      'maintenanceTips': maintenanceTips,
      'vigor': vigor,
      'coeficient_kc': kc,
      'speciesId': speciesId,
      'reference': reference,
      'isVeteran': isVeteran,
      'initialAge': initialAge,
      'height': height,
      'trunkDiameter': trunkDiameter,
      'soilBalance': soilBalance,
      'calculatedRegArea': calculatedRegArea,
      'lastBalanceUpdate': lastBalanceUpdate != null
          ? Timestamp.fromDate(lastBalanceUpdate!)
          : null,
      'timeline': timeline.map((e) => e.toMap()).toList(),
    };
  }

  factory Tree.fromMap(Map<String, dynamic> map, String id) {
    return Tree(
      id: id,
      species: map['species'] ?? '',
      commonName: map['commonName'] ?? '',
      photoUrl: map['photoUrl'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      plantingDate:
          (map['plantingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'Viable',
      notes: map['notes'] ?? '',
      fincaId: map['fincaId'],
      ecologicalFunction: map['ecologicalFunction'],
      plantingFormat: map['plantingFormat'],
      provider: map['provider'],
      price: (map['price'] as num?)?.toDouble(),
      padrino: map['padrino'],
      maintenanceTips: map['maintenanceTips'],
      vigor: map['vigor'],
      kc: (map['coeficient_kc'] as num?)
          ?.toDouble(), // Mapped from coeficient_kc
      speciesId: map['speciesId'],
      reference: map['reference'],
      isVeteran: map['isVeteran'] ?? false,
      initialAge: (map['initialAge'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble(),
      trunkDiameter: (map['trunkDiameter'] as num?)?.toDouble(),
      soilBalance: (map['soilBalance'] as num?)?.toDouble(),
      calculatedRegArea: (map['calculatedRegArea'] as num?)?.toDouble(),
      lastBalanceUpdate: (map['lastBalanceUpdate'] as Timestamp?)?.toDate(),
      timeline: map['timeline'] != null
          ? (map['timeline'] as List<dynamic>)
                .map((e) => TreeEvent.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}
