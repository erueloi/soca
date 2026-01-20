import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/species.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

final speciesRepositoryProvider = Provider((ref) {
  final config = ref.watch(farmConfigStreamProvider).value;
  return SpeciesRepository(fincaId: config?.fincaId);
});

class SpeciesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? fincaId;

  SpeciesRepository({this.fincaId});

  Stream<List<Species>> getSpecies() {
    if (fincaId == null) {
      debugPrint('SpeciesRepo: FincaId null, returning empty list');
      return Stream.value([]);
    }

    return _firestore
        .collection('species')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('commonName')
        .snapshots()
        .map((snapshot) {
          debugPrint('SpeciesRepo: Loaded ${snapshot.docs.length} species.');
          return snapshot.docs
              .map((doc) => Species.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((e) {
          debugPrint('SpeciesRepo: Error loading species: $e');
          return <Species>[];
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
    if (fincaId == null) throw Exception('No FincaId');
    final s = species.copyWith(fincaId: fincaId);
    final ref = await _firestore.collection('species').add(s.toMap());
    return ref.id;
  }

  Future<void> updateSpecies(Species species) async {
    if (species.id.isEmpty) return;
    // Ensure we preserve fincaId if we update
    final s = species.copyWith(fincaId: fincaId);
    await _firestore.collection('species').doc(species.id).update(s.toMap());
  }

  Future<void> seedLibrary() async {
    if (fincaId == null) return;

    final collection = _firestore.collection('species');
    // Check purely by fincaId to avoid duplicates per finca
    final snapshot = await collection
        .where('fincaId', isEqualTo: fincaId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return; // Already populated for this finca
    }

    final batch = _firestore.batch();
    for (var s in _localKnowledgeBase.values) {
      final docRef = collection.doc();
      // Inject FincaID into seed data
      batch.set(docRef, s.copyWith(fincaId: fincaId).toMap());
    }
    await batch.commit();
  }

  Future<Map<String, int>> fixMissingPrefixes() async {
    if (fincaId == null) return {'updated': 0};

    int updated = 0;
    // Only fix MY species
    final collection = _firestore.collection('species');
    final snapshot = await collection
        .where('fincaId', isEqualTo: fincaId)
        .get();
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

  // Offline Knowledge Base
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
      color: '4CAF50', // Green
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
      plantingMonths: [3, 4],
      adultHeight: 8.0,
      adultDiameter: 6.0,
      growthRate: 'Lent',
      droughtResistance: 5,
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
      color: 'F06292', // Pink
      iconCode: 58683, // Icons.park.codePoint
      iconName: 'park',
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
      color: '795548', // Brown
      iconCode: 58683, // Icons.park.codePoint
      iconName: 'park',
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
      color: 'FF9800', // Orange
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      color: '1B5E20', // Dark Green
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      color: '388E3C', // Green
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      color: '9C27B0', // Purple
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      color: '9C27B0', // Purple
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      pruningMonths: [5, 6],
      harvestMonths: [5, 6],
      floweringMonths: [4],
      sunNeeds: 'Alt',
      color: 'F44336', // Red
      iconCode: 58683, // Icons.park.codePoint
      iconName: 'park',
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
      color: 'CDDC39', // Lime
      iconCode: 58668, // Icons.nature.codePoint
      iconName: 'nature',
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
      color: 'E91E63', // Pink/Red
      iconCode: 58683, // Icons.park.codePoint
      iconName: 'park',
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
      color: '5D4037', // Dark Brown
      iconCode: 58683, // Icons.park.codePoint
      iconName: 'park',
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
      pruningMonths: [3, 4, 9, 10],
      harvestMonths: [],
      floweringMonths: [2, 3],
      sunNeeds: 'Alt',
      color: '004D40', // Dark Teal
      iconCode:
          984534, // Icons.forest.codePoint (Approximate, using dummy or direct replacement if needed. Better: use Icons.forest.codePoint but I need 'import package:flutter/material.dart')
      iconName: 'forest',
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
      color: '4E342E', // Brown
      iconCode: 58683, // Icons.park
      iconName: 'park',
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
      color: '2E7D32', // Green
      iconCode: 984534, // Icons.forest
      iconName: 'forest',
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
      color: 'F44336', // Red
      iconCode: 58683, // Icons.park
      iconName: 'park',
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
      color: '8BC34A', // Light Green
      iconCode: 58683, // Icons.park
      iconName: 'park',
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
      color: 'AB47BC', // Purple
      iconCode: 58683, // Icons.park
      iconName: 'park',
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
      color: 'FFB74D', // Orange
      iconCode: 58683, // Icons.park
      iconName: 'park',
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
      pruningMonths: [6, 7],
      harvestMonths: [],
      floweringMonths: [4, 5, 6],
      sunNeeds: 'Alt',
      color: 'EC407A', // Pink
      iconCode: 58668, // Icons.grass -> nature (fallback)
      iconName: 'grass',
    ),
    'ziziphus jujuba': Species(
      id: '',
      commonName: 'Ginjoler',
      scientificName: 'Ziziphus jujuba',
      kc: 0.65,
      leafType: 'Caduca',
      frostSensitivity: 'Baixa',
      fruit: true,
      prefix: 'GIN',
      pruningMonths: [1, 2],
      harvestMonths: [9, 10],
      floweringMonths: [5, 6],
      sunNeeds: 'Alt',
      color: 'F06292', // Pink
      iconCode: 58683, // Icons.park
      iconName: 'park',
    ),
  };

  Species? findOfflineSpecies(String query) {
    final lowerQuery = query.toLowerCase().trim();
    if (_localKnowledgeBase.containsKey(lowerQuery)) {
      return _localKnowledgeBase[lowerQuery];
    }
    try {
      return _localKnowledgeBase.values.firstWhere(
        (s) =>
            s.scientificName.toLowerCase() == lowerQuery ||
            s.commonName.toLowerCase() == lowerQuery,
      );
    } catch (_) {
      return _inferFromGenus(lowerQuery);
    }
  }

  Species _inferFromGenus(String query) {
    final genus = query.split(' ').first.toLowerCase();
    String color = '9E9E9E';
    int icon = 58683; // Icons.park
    String iconName = 'park';

    if ([
      'pinus',
      'cupressus',
      'abies',
      'cedrus',
      'juniperus',
    ].contains(genus)) {
      color = '2E7D32';
      icon = 984534;
      iconName = 'forest';
    } else if (['citrus'].contains(genus)) {
      color = 'FF9800';
      icon = 58668;
      iconName = 'nature';
    } else if (['prunus', 'malus', 'pyrus'].contains(genus)) {
      color = 'F06292';
      icon = 58683;
      iconName = 'park';
    } else if (['quercus', 'ficus', 'acer', 'ulmus', 'olea'].contains(genus)) {
      color = '795548';
      icon = 58668;
      iconName = 'nature';
    } else {
      final palette = [
        'EF5350',
        'AB47BC',
        '5C6BC0',
        '29B6F6',
        '26A69A',
        '9CCC65',
        'FFCA28',
        'FF7043',
        '8D6E63',
      ];
      color = palette[query.hashCode.abs() % palette.length];
    }

    return Species(
      id: '',
      commonName: query,
      scientificName: query,
      kc: 0.75,
      leafType: 'Fulla',
      frostSensitivity: 'Mitjana',
      fruit: true,
      prefix: query
          .substring(0, query.length < 3 ? query.length : 3)
          .toUpperCase(),
      color: color,
      iconCode: icon,
      iconName: iconName,
      plantingMonths: [3, 4],
    );
  }
}
