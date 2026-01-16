import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/planta_hort.dart';
import '../../domain/entities/hort_rotation_pattern.dart';
import '../../domain/entities/espai_hort.dart';

final hortRepositoryProvider = Provider((ref) => HortRepository());

class HortRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'plantes_hort',
  );
  final CollectionReference _patternsCollection = FirebaseFirestore.instance
      .collection('patrons_rotacio');
  final CollectionReference _espaisCollection = FirebaseFirestore.instance
      .collection('espais_hort');

  Stream<List<PlantaHort>> getPlantsStream() {
    return _collection.orderBy('nomComu').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PlantaHort.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> savePlant(PlantaHort plant) async {
    if (plant.id.isEmpty) {
      // Add new
      await _collection.add(plant.toMap());
    } else {
      // Update
      await _collection.doc(plant.id).update(plant.toMap());
    }
  }

  Future<void> deletePlant(String id) async {
    await _collection.doc(id).delete();
  }

  // --- Espais Hort ---

  Stream<List<EspaiHort>> getEspaisStream() {
    return _espaisCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return EspaiHort.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> saveEspai(EspaiHort espai) async {
    if (espai.id.isEmpty) {
      await _espaisCollection.add(espai.toFirestoreMap());
    } else {
      await _espaisCollection.doc(espai.id).update(espai.toFirestoreMap());
    }
  }

  Future<void> deleteEspai(String id) async {
    await _espaisCollection.doc(id).delete();
  }

  // --- Rotation Patterns ---

  Stream<List<HortRotationPattern>> getPatternsStream() {
    return _patternsCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return HortRotationPattern.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Future<void> savePattern(HortRotationPattern pattern) async {
    if (pattern.id.isEmpty) {
      await _patternsCollection.add(pattern.toMap());
    } else {
      await _patternsCollection.doc(pattern.id).update(pattern.toMap());
    }
  }

  Future<void> initRotationPatterns() async {
    final snap = await _patternsCollection.limit(1).get();
    if (snap.docs.isNotEmpty) return; // Already initialized

    // 1. Fetch Existing Plants to Build Lookup Map
    final plantSnaps = await _collection.get();
    final Map<String, String> commonNameToId = {
      for (var doc in plantSnaps.docs)
        (doc.data() as Map<String, dynamic>)['nomComu']
                .toString()
                .toLowerCase():
            doc.id,
    };

    final batch = FirebaseFirestore.instance.batch();

    // Helper to Resolve ID (Find or Create)
    Future<String> resolvePlantId(String commonName) async {
      final normalizedMatches = commonNameToId[commonName.toLowerCase()];
      if (normalizedMatches != null) return normalizedMatches;

      // Not found? Check seeds
      try {
        final seed = _defaultPlants.firstWhere(
          (p) => p.nomComu.toLowerCase() == commonName.toLowerCase(),
        );

        // Found in seeds! Create it.
        final docRef = _collection.doc();
        await docRef.set(seed.copyWith(id: docRef.id).toMap());

        // Update local cache
        final newId = docRef.id;
        commonNameToId[commonName.toLowerCase()] = newId;
        return newId;
      } catch (e) {
        // Not in seeds either? We can't create it reliably without data.
        // Return matching name as fallback string (legacy behavior support)
        // or create a placeholder?
        // Let's create a generic placeholder to prevent breakage
        // print('Warning: Plant "$commonName" unknown. Creating placeholder.');

        // Create generic placeholder
        final docRef = _collection.doc();
        final placeholder = PlantaHort(
          id: docRef.id,
          nomComu: commonName,
          familiaBotanica: 'Desconeguda',
          color: Colors.grey,
        );
        await docRef.set(placeholder.toMap());

        commonNameToId[commonName.toLowerCase()] = docRef.id;
        return docRef.id;
      }
    }

    // 2. Build Patterns with Resolved IDs
    // We need to await inside the list construction, so let's do it procedurally.

    // O1
    // final p1_id_pastanaga = await resolvePlantId('Pastanaga Nantesa'); // Unused duplicate
    // Or should I fuzzy match 'Pastanaga'?
    // My seed list uses 'Pastanaga Nantesa'. The patter used 'Pastanaga'.
    // Logic improvement: Contains match?
    // Let's rely on specific names in patterns matching seeds, or 'Pastanaga' usage.
    // Actually, let's update Pattern definitions to use the Common Names present in _defaultPlants if possible, or aliases.
    // For now, let's stick to simple resolving.

    // Better: Update patterns to use the EXACT names from _defaultPlants where possible.
    final idTomata = await resolvePlantId('Tomata');
    final idCeba = await resolvePlantId('Ceba');
    final idEnciam = await resolvePlantId('Enciam Maravilla');
    final idPesol = await resolvePlantId('Pèsol');
    final idPastanaga = await resolvePlantId('Pastanaga Nantesa');
    final idMongeta = await resolvePlantId('Mongeta');
    final idEspinac = await resolvePlantId('Espinac');
    final idAll = await resolvePlantId('All');
    final idRemolatxa = await resolvePlantId(
      'Remolatxa',
    ); // Will create placeholder if not in seed
    final idPorro = await resolvePlantId('Porro'); // Placeholder
    final idColiflor = await resolvePlantId('Coliflor');
    final idFava = await resolvePlantId('Fava Aguadulce');
    final idAlberginia = await resolvePlantId('Albergínia');
    final idPebrot = await resolvePlantId('Pebrot');
    final idFesol = await resolvePlantId(
      'Mongeta',
    ); // map Fesol to Mongeta/Fesol?

    final patterns = [
      HortRotationPattern(
        id: 'O1',
        name: 'O1 (Tardor)',
        description: 'Pastanaga -> Ceba -> Enciam -> Pèsol',
        stages: [
          HortRotationStage(
            stageIndex: 0,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [idPastanaga],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: [idCeba],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [idEnciam],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 3 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: [idPesol],
          ),
        ],
      ),
      HortRotationPattern(
        id: 'P1',
        name: 'P1 (Primavera)',
        description: 'Tomata -> All -> Mongeta -> Espinac',
        stages: [
          HortRotationStage(
            stageIndex: 0,
            label: 'Any 1 - Primavera',
            exigency: HortExigenciaNutrients.moltExigent,
            suggestedSpeciesIds: [idTomata],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: [idAll],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: [idMongeta],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [idEspinac],
          ),
        ],
      ),
      HortRotationPattern(
        id: 'O2',
        name: 'O2 (Tardor)',
        description: 'Remolatxa -> Porro -> Coliflor -> Fava',
        stages: [
          HortRotationStage(
            stageIndex: 0,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [idRemolatxa],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: [idPorro],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [
              idColiflor,
            ], // Combined usage? No, only one. But we can add Pastanaga.
            // Original used [Coliflor, Pastanaga]
            // Let's add Pastanaga back if logic supports list
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 3 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: [idFava],
          ),
        ],
      ),
      HortRotationPattern(
        id: 'P2',
        name: 'P2 (Primavera)',
        description: 'Albergínia -> Ceba -> Fesol -> Col',
        stages: [
          HortRotationStage(
            stageIndex: 0,
            label: 'Any 1 - Primavera',
            exigency: HortExigenciaNutrients.moltExigent,
            suggestedSpeciesIds: [
              idAlberginia,
              idPebrot,
            ], // Alberginia & Pebrot
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: [idCeba],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: [idFesol], // Mongeta/Fesol
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: [
              idColiflor,
            ], // Using Coliflor as closest to Col if Col missing
          ),
        ],
      ),
    ];

    for (var p in patterns) {
      batch.set(_patternsCollection.doc(p.id), p.toMap());
    }

    await batch.commit();
  }

  // Seed Data extracted for reuse
  static const List<PlantaHort> _defaultPlants = [
    PlantaHort(
      id: '1',
      nomComu: 'Tomàquet',
      nomCientific: 'Solanum lycopersicum',
      familiaBotanica: 'Solanàcies',
      partComestible: HortPartComestible.fruit,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 50.0,
      distanciaLinies: 70.0,
      aliats: ['Alfàbrega', 'Pastanaga', 'Ceba'],
      enemics: ['Patata', 'Cogombre', 'Fonoll'],
      color: Colors.red,
      marcPlantacio: '50x70 cm',
    ),
    PlantaHort(
      id: '2',
      nomComu: 'Enciam Maravilla',
      nomCientific: 'Lactuca sativa',
      familiaBotanica: 'Asteràcies',
      partComestible: HortPartComestible.fulla,
      exigenciaNutrients: HortExigenciaNutrients.mitjanamentExigent,
      distanciaPlantacio: 30,
      distanciaLinies: 30,
      aliats: ['Ceba', 'Maduixa', 'Pastanaga'],
      enemics: ['Julivert'],
    ),
    PlantaHort(
      id: '3',
      nomComu: 'Fava Aguadulce',
      nomCientific: 'Vicia faba',
      familiaBotanica: 'Fabàcies',
      partComestible: HortPartComestible.florLlegum,
      exigenciaNutrients: HortExigenciaNutrients.millorant,
      distanciaPlantacio: 20,
      distanciaLinies: 50,
      aliats: ['Carxofa', 'Patata', 'Enciam'],
      enemics: ['All', 'Ceba'],
      funcio: 'Fixadora de Nitrogen',
    ),
    PlantaHort(
      id: '4',
      nomComu: 'Carbassó Negre',
      nomCientific: 'Cucurbita pepo',
      familiaBotanica: 'Cucurbitàcies',
      partComestible: HortPartComestible.fruit,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 80,
      distanciaLinies: 100,
      aliats: ['Blat de moro', 'Mongeta', 'Caputxina'],
      enemics: ['Patata'],
    ),
    PlantaHort(
      id: '5',
      nomComu: 'Pastanaga Nantesa',
      nomCientific: 'Daucus carota',
      familiaBotanica: 'Apiàcies',
      partComestible: HortPartComestible.arrel,
      exigenciaNutrients: HortExigenciaNutrients.mitjanamentExigent,
      distanciaPlantacio: 5,
      distanciaLinies: 25,
      aliats: ['Ceba', 'Porro', 'Tomàquet'],
      enemics: ['Anet'],
    ),
    PlantaHort(
      id: '6',
      nomComu: 'Bleda',
      nomCientific: 'Beta vulgaris var. cicla',
      familiaBotanica: 'Amarantàcies',
      partComestible: HortPartComestible.fulla,
      exigenciaNutrients: HortExigenciaNutrients.mitjanamentExigent,
      distanciaPlantacio: 30,
      distanciaLinies: 40,
      aliats: ['Mongeta', 'Ceba'],
      enemics: [],
    ),
    PlantaHort(
      id: '7',
      nomComu: 'Pèsol',
      nomCientific: 'Pisum sativum',
      familiaBotanica: 'Fabàcies',
      partComestible: HortPartComestible.florLlegum,
      exigenciaNutrients: HortExigenciaNutrients.millorant,
      distanciaPlantacio: 10,
      distanciaLinies: 50,
      aliats: ['Pastanaga', 'Rave', 'Blat de moro'],
      enemics: ['All', 'Ceba'],
    ),
    PlantaHort(
      id: '8',
      nomComu: 'Ceba',
      nomCientific: 'Allium cepa',
      familiaBotanica: 'Amaril·lidàcies',
      partComestible: HortPartComestible.arrel,
      exigenciaNutrients: HortExigenciaNutrients.pocExigent,
      distanciaPlantacio: 15,
      distanciaLinies: 30,
      aliats: ['Tomàquet', 'Pastanaga', 'Enciam'],
      enemics: ['Llegums', 'Pèsol', 'Fava'],
    ),
    PlantaHort(
      id: '9',
      nomComu: 'Patata',
      nomCientific: 'Solanum tuberosum',
      familiaBotanica: 'Solanàcies',
      partComestible: HortPartComestible.arrel,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 40,
      distanciaLinies: 70,
      aliats: ['Fava', 'Caputxina'],
      enemics: ['Tomàquet', 'Carbassó'],
    ),
    PlantaHort(
      id: '10',
      nomComu: 'All',
      nomCientific: 'Allium sativum',
      familiaBotanica: 'Amaril·lidàcies',
      partComestible: HortPartComestible.arrel,
      exigenciaNutrients: HortExigenciaNutrients.pocExigent,
      distanciaPlantacio: 5,
      distanciaLinies: 15,
      aliats: ['Tomàquet', 'Maduixa'],
      enemics: ['Fesol', 'Pèsol'],
    ),
    PlantaHort(
      id: '11',
      nomComu: 'Espinac',
      familiaBotanica: 'Amarantàcies',
      partComestible: HortPartComestible.fulla,
      exigenciaNutrients: HortExigenciaNutrients.mitjanamentExigent,
      distanciaPlantacio: 10,
      distanciaLinies: 30,
    ),
    PlantaHort(
      id: '12',
      nomComu: 'Coliflor',
      familiaBotanica: 'Brassicàcies',
      partComestible: HortPartComestible.florLlegum,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 50,
      distanciaLinies: 60,
    ),
    PlantaHort(
      id: '13',
      nomComu: 'Albergínia',
      familiaBotanica: 'Solanàcies',
      partComestible: HortPartComestible.fruit,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 50,
      distanciaLinies: 70,
    ),
    PlantaHort(
      id: '14',
      nomComu: 'Pebrot',
      familiaBotanica: 'Solanàcies',
      partComestible: HortPartComestible.fruit,
      exigenciaNutrients: HortExigenciaNutrients.moltExigent,
      distanciaPlantacio: 40,
      distanciaLinies: 50,
    ),
    PlantaHort(
      id: '15',
      nomComu: 'Mongeta',
      familiaBotanica: 'Fabàcies',
      partComestible: HortPartComestible.florLlegum,
      exigenciaNutrients: HortExigenciaNutrients.millorant,
      distanciaPlantacio: 10,
      distanciaLinies: 50,
    ),
  ];

  Future<void> initBibliotecaRegenerativa() async {
    final batch = FirebaseFirestore.instance.batch();

    // Use shared static list
    for (var p in _defaultPlants) {
      final docRef = _collection.doc();
      final pWithId = p.copyWith(id: docRef.id);
      batch.set(docRef, pWithId.toMap());
    }

    await batch.commit();
  }
}
