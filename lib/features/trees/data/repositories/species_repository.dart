import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/species.dart';

final speciesRepositoryProvider = Provider((ref) => SpeciesRepository());

class SpeciesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Species>> getSpecies() {
    return _firestore
        .collection('species')
        .orderBy('commonName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Species.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<Species?> getSpeciesById(String id) async {
    final doc = await _firestore.collection('species').doc(id).get();
    if (doc.exists) {
      return Species.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<String> addSpecies(Species species) async {
    final ref = await _firestore.collection('species').add(species.toMap());
    return ref.id;
  }

  Future<void> updateSpecies(Species species) async {
    if (species.id.isEmpty) return;
    await _firestore
        .collection('species')
        .doc(species.id)
        .update(species.toMap());
  }

  // Offline Knowledge Base (Lleida / Mediterranean Focus)
  static final Map<String, Species> _localKnowledgeBase = {
    'olea europaea': Species(
      id: '',
      commonName: 'Olivera',
      scientificName: 'Olea europaea',
      kc: 0.60,
      leafType: 'Perenne',
      frostSensitivity: 'Baixa (-10°C)',
      fruit: true,
      prefix: 'OLI',
      pruningMonths: [12, 1, 2],
      harvestMonths: [11, 12, 1],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
    ),
    'prunus dulcis': Species(
      id: '',
      commonName: 'Ametller',
      scientificName: 'Prunus dulcis',
      kc: 0.70,
      leafType: 'Caduca',
      frostSensitivity: 'Mitjana (floració)',
      fruit: true,
      prefix: 'AME',
      pruningMonths: [12, 1, 2], // Winter
      harvestMonths: [8, 9], // Aug/Sept
      floweringMonths: [2, 3], // Early bloom
      sunNeeds: 'Alt',
    ),
    'juglans regia': Species(
      id: '',
      commonName: 'Noguer',
      scientificName: 'Juglans regia',
      kc: 1.00,
      leafType: 'Caduca',
      frostSensitivity: 'Mitjana',
      fruit: true,
      prefix: 'NOG',
      pruningMonths: [12, 1],
      harvestMonths: [9, 10],
      floweringMonths: [4, 5],
      sunNeeds: 'Alt',
    ),
    'diospyros kaki': Species(
      id: '',
      commonName: 'Caqui',
      scientificName: 'Diospyros kaki',
      kc: 0.75,
      leafType: 'Caduca',
      frostSensitivity: 'Mitjana',
      fruit: true,
      prefix: 'CAQ',
      pruningMonths: [2, 3],
      harvestMonths: [10, 11],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
    ),
    'quercus ilex': Species(
      id: '',
      commonName: 'Alzina',
      scientificName: 'Quercus ilex',
      kc: 0.45,
      leafType: 'Perenne',
      frostSensitivity: 'Molt Baixa',
      fruit: false,
      prefix: 'ALZ',
      pruningMonths: [11, 12, 1, 2], // Formation
      harvestMonths: [],
      floweringMonths: [4, 5],
      sunNeeds: 'Alt',
    ),
    'quercus pubescens': Species(
      id: '',
      commonName: 'Roure',
      scientificName: 'Quercus pubescens',
      kc: 0.55,
      leafType: 'Caduca',
      frostSensitivity: 'Molt Baixa',
      fruit: false,
      prefix: 'ROU',
      pruningMonths: [11, 12, 1, 2],
      harvestMonths: [],
      floweringMonths: [4, 5],
      sunNeeds: 'Alt',
    ),
    'ficus carica': Species(
      id: '',
      commonName: 'Figuera',
      scientificName: 'Ficus carica',
      kc: 0.75,
      leafType: 'Caduca',
      frostSensitivity: 'Mitjana',
      fruit: true,
      prefix: 'FIG',
      pruningMonths: [12, 1, 2],
      harvestMonths: [8, 9, 10],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
    ),
    'vitis vinifera': Species(
      id: '',
      commonName: 'Vinya',
      scientificName: 'Vitis vinifera',
      kc: 0.65,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'VIN',
      pruningMonths: [1, 2],
      harvestMonths: [9, 10],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
    ),
    'prunus avium': Species(
      id: '',
      commonName: 'Cirerer',
      scientificName: 'Prunus avium',
      kc: 0.90,
      leafType: 'Caduca',
      frostSensitivity: 'Alta (floració)',
      fruit: true,
      prefix: 'CIR',
      pruningMonths: [5, 6], // Green pruning after harvest often preferred
      harvestMonths: [5, 6],
      floweringMonths: [4],
      sunNeeds: 'Alt',
    ),
    'cydonia oblonga': Species(
      id: '',
      commonName: 'Codonyer',
      scientificName: 'Cydonia oblonga',
      kc: 0.85,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'COD',
      pruningMonths: [12, 1, 2],
      harvestMonths: [9, 10],
      floweringMonths: [4, 5],
      sunNeeds: 'Alt',
    ),
    'punica granatum': Species(
      id: '',
      commonName: 'Granat',
      scientificName: 'Punica granatum',
      kc: 0.65,
      leafType: 'Caduca',
      frostSensitivity: 'Mitjana',
      fruit: true,
      prefix: 'GRA',
      pruningMonths: [1, 2],
      harvestMonths: [9, 10, 11],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
    ),
    'ceratonia siliqua': Species(
      id: '',
      commonName: 'Garrofer',
      scientificName: 'Ceratonia siliqua',
      kc: 0.40,
      leafType: 'Perenne',
      frostSensitivity: 'Alta (-4°C)',
      fruit: true,
      prefix: 'GAR',
      pruningMonths: [5, 6], // After harvest/risk of frost
      harvestMonths: [9, 10],
      floweringMonths: [8, 9, 10],
      sunNeeds: 'Alt',
    ),
    'cupressus': Species(
      id: '',
      commonName: 'Xiprer',
      scientificName: 'Cupressus',
      kc: 0.50,
      leafType: 'Perenne',
      frostSensitivity: 'Baixa',
      fruit: false,
      prefix: 'XIP',
      pruningMonths: [3, 4, 9, 10], // Hedges
      harvestMonths: [],
      floweringMonths: [2, 3],
      sunNeeds: 'Alt',
    ),
    'celtis australis': Species(
      id: '',
      commonName: 'Lledoner',
      scientificName: 'Celtis australis',
      kc: 0.55,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: false,
      prefix: 'LLE',
      pruningMonths: [11, 12, 1, 2],
      harvestMonths: [],
      floweringMonths: [4, 5],
      sunNeeds: 'Alt',
    ),
    'pinus halepensis': Species(
      id: '',
      commonName: 'Pi Blanc',
      scientificName: 'Pinus halepensis',
      kc: 0.35,
      leafType: 'Perenne',
      frostSensitivity: 'Molt Baixa',
      fruit: false,
      prefix: 'PIN',
      pruningMonths: [11, 12, 1],
      harvestMonths: [],
      floweringMonths: [3, 4],
      sunNeeds: 'Alt',
    ),
    'malus domestica': Species(
      id: '',
      commonName: 'Pomera',
      scientificName: 'Malus domestica',
      kc: 0.95,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'POM',
      pruningMonths: [12, 1, 2],
      harvestMonths: [9, 10],
      floweringMonths: [4],
      sunNeeds: 'Alt',
    ),
    'pyrus communis': Species(
      id: '',
      commonName: 'Perer',
      scientificName: 'Pyrus communis',
      kc: 0.90,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'PER',
      pruningMonths: [12, 1, 2],
      harvestMonths: [8, 9],
      floweringMonths: [4],
      sunNeeds: 'Alt',
    ),
    'morus alba': Species(
      id: '',
      commonName: 'Morera',
      scientificName: 'Morus alba',
      kc: 0.75,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'MOR',
      pruningMonths: [11, 12, 1, 2],
      harvestMonths: [6],
      floweringMonths: [4],
      sunNeeds: 'Alt',
    ),
    'prunus armeniaca': Species(
      id: '',
      commonName: 'Albercoc',
      scientificName: 'Prunus armeniaca',
      kc: 0.85,
      leafType: 'Caduca',
      frostSensitivity: 'Alta (floració)',
      fruit: true,
      prefix: 'ALB',
      pruningMonths: [12, 1],
      harvestMonths: [6, 7],
      floweringMonths: [2, 3],
      sunNeeds: 'Alt',
    ),
    'cistus': Species(
      id: '',
      commonName: 'Estepa',
      scientificName: 'Cistus',
      kc: 0.30,
      leafType: 'Perenne',
      frostSensitivity: 'Baixa',
      fruit: false,
      prefix: 'EST',
      pruningMonths: [6, 7], // After flowering
      harvestMonths: [],
      floweringMonths: [4, 5, 6],
      sunNeeds: 'Alt',
    ),
  };

  /// Smart Agent: Find species data offline by scientific or common name
  Species? findOfflineSpecies(String query) {
    final lowerQuery = query.toLowerCase().trim();
    // 1. Try exact scientific key
    if (_localKnowledgeBase.containsKey(lowerQuery)) {
      return _localKnowledgeBase[lowerQuery];
    }
    // 2. Iterate to find match in scientific or common name
    try {
      return _localKnowledgeBase.values.firstWhere(
        (s) =>
            s.scientificName.toLowerCase() == lowerQuery ||
            s.commonName.toLowerCase() == lowerQuery,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> seedLibrary() async {
    final collection = _firestore.collection('species');
    final snapshot = await collection.limit(1).get();

    if (snapshot.docs.isNotEmpty) {
      // OPTIONAL: Force update if we want to migrate old data structure.
      // For now, only seed if empty.
      return;
    }

    final batch = _firestore.batch();
    for (var s in _localKnowledgeBase.values) {
      final docRef = collection.doc();
      batch.set(docRef, s.toMap());
    }
    await batch.commit();
  }

  Future<Map<String, int>> fixMissingPrefixes() async {
    int updated = 0;
    final collection = _firestore.collection('species');
    final snapshot = await collection.get();
    final batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      String? prefix = data['prefix'];

      if (prefix == null || prefix.isEmpty) {
        final commonName = data['commonName'] as String? ?? 'UNK';
        final cleanName = commonName.toUpperCase().replaceAll(
          RegExp(r'[^A-Z]'),
          '',
        );
        prefix = cleanName.length >= 3
            ? cleanName.substring(0, 3)
            : cleanName.padRight(3, 'X');

        batch.update(doc.reference, {'prefix': prefix});
        updated++;
      }
    }

    if (updated > 0) {
      await batch.commit();
    }
    return {'updated': updated};
  }
}
