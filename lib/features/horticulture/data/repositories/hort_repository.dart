import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import '../../domain/entities/planta_hort.dart';

class HortRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'plantes_hort',
  );

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

  // Seed Data Logic (Regenerative Agriculture)
  Future<void> initBibliotecaRegenerativa() async {
    // Check if collection is empty to avoid overwriting user data
    // Or maybe just add missing ones? For safety, let's only run if empty or explicitly requested.
    // The UI handles the confirmation prompt.

    final batch = FirebaseFirestore.instance.batch();

    final List<PlantaHort> seedData = [
      PlantaHort(
        id: '', // Will be generated
        nomComu: 'Tomata',
        nomCientific: 'Solanum lycopersicum',
        familiaBotanica: 'Solanàcies',
        partComestible: HortPartComestible.fruit,
        exigenciaNutrients: HortExigenciaNutrients.exhauridora,
        distanciaPlantacio: 50.0,
        distanciaLinies: 70.0,
        aliats: ['Alfàbrega', 'Pastanaga', 'Ceba'],
        enemics: [
          'Patata',
          'Cogombre',
          'Fonoll',
        ], // Solanaceae hate each other mostly
        color: Colors.red,
        marcPlantacio: '50x70 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Alfàbrega',
        nomCientific: 'Ocimum basilicum',
        familiaBotanica: 'Lamiàcies',
        partComestible: HortPartComestible.fulla,
        exigenciaNutrients: HortExigenciaNutrients.consumidora,
        distanciaPlantacio: 25.0,
        distanciaLinies: 30.0,
        aliats: ['Tomata', 'Pebrot'],
        enemics: ['Ruda'],
        color: Colors.greenAccent,
        marcPlantacio: '25x30 cm',
        funcio: 'Repulsiu',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Fesol',
        nomCientific: 'Phaseolus vulgaris',
        familiaBotanica: 'Fabàcies',
        partComestible: HortPartComestible.florLlegum,
        exigenciaNutrients: HortExigenciaNutrients.millorant,
        distanciaPlantacio: 30.0,
        distanciaLinies: 50.0,
        aliats: [
          'Panís',
          'Carbassa',
          'Pastanaga',
        ], // 3 Sisters (Panís/Fesol/Carbassa)
        enemics: ['Ceba', 'All', 'Porro'], // Legumes hate Alliums
        color: Colors.brown[400]!,
        marcPlantacio: '30x50 cm',
        funcio: 'Nitrogenadora',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Panís',
        nomCientific: 'Zea mays',
        familiaBotanica: 'Poàcies',
        partComestible: HortPartComestible.fruit, // Cereal
        exigenciaNutrients: HortExigenciaNutrients.exhauridora,
        distanciaPlantacio: 30.0,
        distanciaLinies: 70.0,
        aliats: ['Fesol', 'Carbassa', 'Pèsol'],
        enemics: ['Tomata'],
        color: Colors.yellow[700]!,
        marcPlantacio: '30x70 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Pastanaga',
        nomCientific: 'Daucus carota',
        familiaBotanica: 'Apiàcies',
        partComestible: HortPartComestible.arrel,
        exigenciaNutrients: HortExigenciaNutrients.consumidora, // Root crop
        distanciaPlantacio: 10.0,
        distanciaLinies: 20.0,
        aliats: ['Porro', 'Tomata', 'Ceba', 'Enciam'],
        enemics: ['Fonoll'], // Same family issues
        color: Colors.orange,
        marcPlantacio: '10x20 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Porro',
        nomCientific: 'Allium ampeloprasum',
        familiaBotanica: 'Amaril·lidàcies',
        partComestible: HortPartComestible.fulla, // Stem/Leaf
        exigenciaNutrients: HortExigenciaNutrients.consumidora,
        distanciaPlantacio: 15.0,
        distanciaLinies: 30.0,
        aliats: ['Pastanaga', 'Api', 'Maduixa'],
        enemics: ['Fesol', 'Pèsol'], // Alliums hate Legumes
        color: Colors.green[300]!,
        marcPlantacio: '15x30 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Pèsol',
        nomCientific: 'Pisum sativum',
        familiaBotanica: 'Fabàcies',
        partComestible: HortPartComestible.florLlegum,
        exigenciaNutrients: HortExigenciaNutrients.millorant,
        distanciaPlantacio: 20.0,
        distanciaLinies: 50.0,
        aliats: ['Panís', 'Pastanaga', 'Rave'],
        enemics: ['Ceba', 'All', 'Porro'],
        color: Colors.lightGreen,
        marcPlantacio: '20x50 cm',
        funcio: 'Nitrogenadora',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Enciam',
        nomCientific: 'Lactuca sativa',
        familiaBotanica: 'Asteràcies',
        partComestible: HortPartComestible.fulla,
        exigenciaNutrients: HortExigenciaNutrients.consumidora,
        distanciaPlantacio: 30.0,
        distanciaLinies: 30.0,
        aliats: ['Pastanaga', 'Rave', 'Maduixa'],
        enemics: ['Julivert'],
        color: Colors.lightGreenAccent[400]!,
        marcPlantacio: '30x30 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Carbassa',
        nomCientific: 'Cucurbita pepo',
        familiaBotanica: 'Cucurbitàcies',
        partComestible: HortPartComestible.fruit,
        exigenciaNutrients: HortExigenciaNutrients.exhauridora,
        distanciaPlantacio: 100.0,
        distanciaLinies: 150.0,
        aliats: ['Panís', 'Fesol', 'Caputxina'],
        enemics: ['Patata'],
        color: Colors.orangeAccent,
        marcPlantacio: '100x150 cm',
      ),
      PlantaHort(
        id: '',
        nomComu: 'Patata',
        nomCientific: 'Solanum tuberosum',
        familiaBotanica: 'Solanàcies',
        partComestible: HortPartComestible.arrel, // Tuber
        exigenciaNutrients: HortExigenciaNutrients
            .exhauridora, // Heavy feeder ("Neteja el terreny")
        distanciaPlantacio: 40.0,
        distanciaLinies: 70.0,
        aliats: [
          'Fesol',
          'Espinac',
          'Caputxina',
        ], // Sometimes beans are ok with potato
        enemics: ['Tomata', 'Carbassa', 'Gira-sol'],
        color: Colors.amber[200]!,
        marcPlantacio: '40x70 cm',
      ),
    ];

    for (var p in seedData) {
      // Use set with a new ID reference to allow batching properly
      final docRef = _collection.doc();
      // Remove empty ID from local object and assign docRef ID if needed,
      // but toMap doesn't send ID to Firestore usually if we separate it.
      // Actually PlantaHort.fromMap reads ID from doc.id.
      // toMap includes 'id'. We should make sure 'id' in data implies document ID or ignore it.
      // Ideally, the document ID IS the source of truth.
      // Let's create a map without ID, or just store it.
      // My toMap includes 'id'. If I store it, I should update it to match docRef.id.
      final pWithId = p.copyWith(id: docRef.id);
      batch.set(docRef, pWithId.toMap());
    }

    await batch.commit();
  }
}
