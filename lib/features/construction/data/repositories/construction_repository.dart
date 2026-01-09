import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/construction_point.dart';

class ConstructionRepository {
  final CollectionReference _pointsCollection = FirebaseFirestore.instance
      .collection('construction_points');
  // We might store floor plans in a separate collection or config doc.
  // Let's store floor plans map in a 'settings' doc or generic 'construction_settings' collection.
  // For simplicity, let's use a dedicated doc 'settings/construction' or similar.
  // But better: A collection 'construction_floors' where we can add floors dynamically if needed?
  // User requested "Llista desplegable per a cada pis". Let's assume fixed known floors or dynamic.
  // Let's allow dynamic floors config stored in Firestore.

  final DocumentReference _floorsConfigDoc = FirebaseFirestore.instance
      .collection('settings')
      .doc('construction_floors');

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- Points ---

  Stream<List<ConstructionPoint>> getPoints(String floorId) {
    return _pointsCollection
        .where('floorId', isEqualTo: floorId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ConstructionPoint.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  Future<void> addPoint(ConstructionPoint point) async {
    await _pointsCollection.add(point.toMap());
  }

  Future<void> updatePoint(ConstructionPoint point) async {
    await _pointsCollection.doc(point.id).update(point.toMap());
  }

  Future<void> deletePoint(String pointId) async {
    await _pointsCollection.doc(pointId).delete();
  }

  // --- Floor Plans ---

  // Returns a Map of floorId -> imageUrl
  Stream<Map<String, String>> getFloorPlans() {
    return _floorsConfigDoc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return {};
      }
      final data = snapshot.data() as Map<String, dynamic>;
      // Expecting structure: { "Planta Baixa": "url1", "Planta 1": "url2" }
      return Map<String, String>.from(data);
    });
  }

  Future<void> saveFloorPlan(String floorId, XFile imageFile) async {
    try {
      final ref = _storage.ref().child(
        'construction_plans/$floorId.jpg', // Overwrite previous plan for same floor is fine
      );

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        await ref.putData(await imageFile.readAsBytes(), metadata);
      } else {
        await ref.putFile(File(imageFile.path), metadata);
      }

      final url = await ref.getDownloadURL();

      // Update config doc
      await _floorsConfigDoc.set({floorId: url}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error uploading floor plan: $e');
      rethrow;
    }
  }

  Future<void> deleteFloorPlan(String floorId) async {
    try {
      // 1. Remove from Firestore Config
      await _floorsConfigDoc.update({floorId: FieldValue.delete()});

      // 2. Delete from Storage
      final ref = _storage.ref().child('construction_plans/$floorId.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting floor plan: $e');
      // It's possible the file doesn't exist if only the config was there, or vice versa.
      // We can swallow the error or rethrow. For UI "remove", robust is better.
    }
  }

  // --- Pathology Images ---

  Future<String?> uploadPathologyImage(XFile imageFile) async {
    try {
      final ref = _storage.ref().child(
        'construction_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        await ref.putData(await imageFile.readAsBytes(), metadata);
      } else {
        await ref.putFile(File(imageFile.path), metadata);
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading pathology image: $e');
      return null;
    }
  }
}
