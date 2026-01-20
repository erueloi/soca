import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/construction_point.dart';

class ConstructionRepository {
  final CollectionReference _pointsCollection = FirebaseFirestore.instance
      .collection('construction_points');
  final CollectionReference _plansCollection = FirebaseFirestore.instance
      .collection('construction_plans');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String? fincaId;

  ConstructionRepository({this.fincaId});

  // --- Points ---

  Stream<List<ConstructionPoint>> getPoints(String floorId) {
    if (fincaId == null) return Stream.value([]);

    return _pointsCollection
        .where('fincaId', isEqualTo: fincaId)
        .where('floorId', isEqualTo: floorId)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'ConstructionRepo: getPoints($floorId) snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return ConstructionPoint.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        })
        .handleError((e) {
          debugPrint('ConstructionRepo: Error in getPoints: $e');
          return <ConstructionPoint>[];
        });
  }

  Stream<List<ConstructionPoint>> getAllPoints() {
    if (fincaId == null) return Stream.value([]);

    return _pointsCollection
        .where('fincaId', isEqualTo: fincaId)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'ConstructionRepo: getAllPoints snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return ConstructionPoint.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        })
        .handleError((e) {
          debugPrint('ConstructionRepo: Error in getAllPoints: $e');
          return <ConstructionPoint>[];
        });
  }

  Future<void> addPoint(ConstructionPoint point) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final pointToSave = point.copyWith(fincaId: fincaId);
    await _pointsCollection.add(pointToSave.toMap());
  }

  Future<void> updatePoint(ConstructionPoint point) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final pointToSave = point.copyWith(fincaId: fincaId);
    await _pointsCollection.doc(point.id).update(pointToSave.toMap());
  }

  Future<void> deletePoint(String pointId) async {
    await _pointsCollection.doc(pointId).delete();
  }

  // --- Floor Plans (Collection Based) ---

  // Returns a Map of floorId (Name) -> imageUrl
  // We map 'name' to 'imageUrl' to keep compatibility with UI that expects Map<String, String>
  Stream<Map<String, String>> getFloorPlans() {
    if (fincaId == null) return Stream.value({});

    return _plansCollection
        .where('fincaId', isEqualTo: fincaId)
        .snapshots()
        .map((snapshot) {
          final result = <String, String>{};
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String?;
            final url = data['imageUrl'] as String?;
            if (name != null && name.isNotEmpty) {
              result[name] = url ?? "";
            }
          }
          debugPrint('ConstructionRepo: Loaded ${result.length} plans.');
          return result;
        })
        .handleError((e) {
          debugPrint('ConstructionRepo: Error loading plans: $e');
          return <String, String>{};
        });
  }

  Future<void> addEmptyFloor(String floorName) async {
    if (fincaId == null) return;

    // Use name as floorId if we want, or just add a new doc with that name
    // To prevent duplicates, we can check efficiently or just add.
    // Let's standardise: Name MUST be unique for UI Map.

    // Check if exists
    final existing = await _plansCollection
        .where('fincaId', isEqualTo: fincaId)
        .where('name', isEqualTo: floorName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _plansCollection.add({
      'fincaId': fincaId,
      'name': floorName,
      'imageUrl': "",
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFloorPlan(String floorName, XFile imageFile) async {
    if (fincaId == null) return;

    try {
      final ref = _storage.ref().child(
        'construction_plans/$fincaId/$floorName.jpg',
      );

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      if (kIsWeb) {
        await ref.putData(await imageFile.readAsBytes(), metadata);
      } else {
        await ref.putFile(File(imageFile.path), metadata);
      }

      final url = await ref.getDownloadURL();

      // Find doc to update or create
      final query = await _plansCollection
          .where('fincaId', isEqualTo: fincaId)
          .where('name', isEqualTo: floorName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'imageUrl': url});
      } else {
        await _plansCollection.add({
          'fincaId': fincaId,
          'name': floorName,
          'imageUrl': url,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error uploading floor plan: $e');
      rethrow;
    }
  }

  Future<void> renameFloor(String oldName, String newName) async {
    if (fincaId == null) return;

    try {
      final query = await _plansCollection
          .where('fincaId', isEqualTo: fincaId)
          .where('name', isEqualTo: oldName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final batch = FirebaseFirestore.instance.batch();

        // 1. Update Name in Plan Doc
        batch.update(doc.reference, {'name': newName});

        // 2. Update FloorId (which is Name) in all Points
        final pointsSnapshot = await _pointsCollection
            .where('fincaId', isEqualTo: fincaId)
            .where('floorId', isEqualTo: oldName)
            .get();

        for (final pDoc in pointsSnapshot.docs) {
          batch.update(pDoc.reference, {'floorId': newName});
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error renaming floor: $e');
      rethrow;
    }
  }

  Future<void> deleteFloorPlan(String floorName) async {
    if (fincaId == null) return;

    try {
      final query = await _plansCollection
          .where('fincaId', isEqualTo: fincaId)
          .where('name', isEqualTo: floorName)
          .limit(1)
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }

      // Cleanup storage?
      final ref = _storage.ref().child(
        'construction_plans/$fincaId/$floorName.jpg',
      );
      try {
        await ref.delete();
      } catch (_) {} // Ignore if not found
    } catch (e) {
      debugPrint('Error deleting floor plan: $e');
    }
  }

  // --- Pathology Images ---

  Future<String?> uploadPathologyImage(XFile imageFile) async {
    final prefix = fincaId != null
        ? 'construction_images/$fincaId'
        : 'construction_images/global';

    try {
      final ref = _storage.ref().child(
        '$prefix/${DateTime.now().millisecondsSinceEpoch}.jpg',
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
