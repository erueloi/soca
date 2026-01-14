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

  Stream<List<ConstructionPoint>> getAllPoints() {
    return _pointsCollection.snapshots().map((snapshot) {
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
      // Filter out null values or convert to String safely
      // Map<String, String>.from might fail if values are not strings.
      // Better manual conversion:
      final result = <String, String>{};
      data.forEach((key, value) {
        if (value is String) {
          result[key] = value;
        } else {
          // Treat null/other as empty string or ignore?
          // If we want it to show up, we need a key.
          result[key] = "";
        }
      });
      return result;
    });
  }

  Future<void> addEmptyFloor(String floorId) async {
    // Store empty string to indicate "no image" but "exists"
    await _floorsConfigDoc.set({floorId: ""}, SetOptions(merge: true));
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

  Future<void> renameFloor(String oldName, String newName) async {
    try {
      final docSnapshot = await _floorsConfigDoc.get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data() as Map<String, dynamic>;
      final url = data[oldName];

      if (url != null) {
        final batch = FirebaseFirestore.instance.batch();

        // 1. Update Config: Remove old key, add new key
        batch.update(_floorsConfigDoc, {
          oldName: FieldValue.delete(),
          newName: url,
        });

        // 2. Update all Points
        final pointsSnapshot = await _pointsCollection
            .where('floorId', isEqualTo: oldName)
            .get();
        for (final doc in pointsSnapshot.docs) {
          batch.update(doc.reference, {'floorId': newName});
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error renaming floor: $e');
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
