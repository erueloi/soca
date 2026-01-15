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

    final batch = FirebaseFirestore.instance.batch();

    // Seed Data (O1, P1, O2, P2)
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
            suggestedSpeciesIds: ['Pastanaga'],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: ['Ceba'],
          ), // Wait, cycle is 6 months?
          // User said: "Una etapa és un cicle de 6 mesos". "Cada 2 anys es completa una volta de 4 etapes".
          // O1 starts in Autumn? Or is O1 just the name of the pattern that generates this sequence?
          // Sequence: 1. Pastanaga (Mitjana) -> 2. Ceba (Poc) -> 3. Enciam (Mitjana) -> 4. Pèsol (Millorant)
          // If starting in Autumn:
          // Stage 1 (Tardor Y1): Pastanaga
          // Stage 2 (Primavera Y2): Ceba
          // Stage 3 (Tardor Y2): Enciam
          // Stage 4 (Primavera Y3): Pèsol
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: ['Enciam', 'Escarola'],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 3 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: ['Pèsol'],
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
            suggestedSpeciesIds: ['Tomata'],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: ['All'],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: ['Mongeta'],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: ['Espinac', 'Bleda'],
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
            suggestedSpeciesIds: ['Remolatxa'],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: ['Porro'],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: ['Coliflor', 'Pastanaga'],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 3 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: ['Fava'],
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
            suggestedSpeciesIds: ['Albergínia', 'Pebrot'],
          ),
          HortRotationStage(
            stageIndex: 1,
            label: 'Any 1 - Tardor',
            exigency: HortExigenciaNutrients.pocExigent,
            suggestedSpeciesIds: ['Ceba'],
          ),
          HortRotationStage(
            stageIndex: 2,
            label: 'Any 2 - Primavera',
            exigency: HortExigenciaNutrients.millorant,
            suggestedSpeciesIds: ['Fesol'],
          ),
          HortRotationStage(
            stageIndex: 3,
            label: 'Any 2 - Tardor',
            exigency: HortExigenciaNutrients.mitjanamentExigent,
            suggestedSpeciesIds: ['Col', 'Coliflor'],
          ),
        ],
      ),
    ];

    for (var p in patterns) {
      // Allow custom ID for seed data
      batch.set(_patternsCollection.doc(p.id), p.toMap());
    }

    await batch.commit();
  }

  Future<void> initBibliotecaRegenerativa() async {
    final batch = FirebaseFirestore.instance.batch();

    final List<PlantaHort> seedData = [
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
        distanciaPlantacio: 10,
        distanciaLinies: 20,
        aliats: ['Tomàquet', 'Maduixa'],
        enemics: ['Fesol', 'Pèsol'],
      ),
    ];

    for (var p in seedData) {
      final docRef = _collection.doc();
      final pWithId = p.copyWith(id: docRef.id);
      batch.set(docRef, pWithId.toMap());
    }

    await batch.commit();
  }
}
