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

  // New Fields
  final String? ecologicalFunction; // Nitrogenadora, Fusta, Fruit...
  final String? plantingFormat; // Alvèol forestal, Arrel nua...
  final String? provider; // Nursery name
  final double? price;
  final String? padrino; // Responsible
  final String? maintenanceTips; // AI or Manual
  final String? vigor; // Alt, Mitjà, Baix
  final List<TreeEvent> timeline;

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
    this.ecologicalFunction,
    this.plantingFormat,
    this.provider,
    this.price,
    this.padrino,
    this.maintenanceTips,
    this.vigor,
    this.timeline = const [],
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
    String? ecologicalFunction,
    String? plantingFormat,
    String? provider,
    double? price,
    String? padrino,
    String? maintenanceTips,
    String? vigor,
    List<TreeEvent>? timeline,
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
      ecologicalFunction: ecologicalFunction ?? this.ecologicalFunction,
      plantingFormat: plantingFormat ?? this.plantingFormat,
      provider: provider ?? this.provider,
      price: price ?? this.price,
      padrino: padrino ?? this.padrino,
      maintenanceTips: maintenanceTips ?? this.maintenanceTips,
      vigor: vigor ?? this.vigor,
      timeline: timeline ?? this.timeline,
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
      'ecologicalFunction': ecologicalFunction,
      'plantingFormat': plantingFormat,
      'provider': provider,
      'price': price,
      'padrino': padrino,
      'maintenanceTips': maintenanceTips,
      'vigor': vigor,
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
      ecologicalFunction: map['ecologicalFunction'],
      plantingFormat: map['plantingFormat'],
      provider: map['provider'],
      price: (map['price'] as num?)?.toDouble(),
      padrino: map['padrino'],
      maintenanceTips: map['maintenanceTips'],
      vigor: map['vigor'],
      timeline: map['timeline'] != null
          ? (map['timeline'] as List<dynamic>)
                .map((e) => TreeEvent.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}
