import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/watering_event.dart';
import '../../domain/entities/evolution_entry.dart';
import '../../domain/entities/ai_analysis_entry.dart';

class TreesRepository {
  final CollectionReference _treesCollection = FirebaseFirestore.instance
      .collection('trees');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Tree>> getTreesStream() {
    return _treesCollection
        .orderBy('plantingDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Tree.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        });
  }

  Future<void> addTree(Tree tree) async {
    await _treesCollection.doc(tree.id).set(tree.toMap());
  }

  Future<void> updateTree(Tree tree) async {
    await _treesCollection.doc(tree.id).update(tree.toMap());
  }

  Future<void> deleteTree(String treeId) async {
    await _treesCollection.doc(treeId).delete();
  }

  Future<String?> uploadTreeImage(XFile imageFile, String treeId) async {
    try {
      final ref = _storage.ref().child(
        'tree_images/$treeId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final bytes = await imageFile.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading tree image: $e');
      return null;
    }
  }

  Future<void> addTimelineEvent(String treeId, TreeEvent event) async {
    await _treesCollection.doc(treeId).update({
      'timeline': FieldValue.arrayUnion([event.toMap()]),
    });
  }

  Stream<List<WateringEvent>> getWateringEventsStream(String treeId) {
    return _treesCollection
        .doc(treeId)
        .collection('regs')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return WateringEvent.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addWateringEvent(String treeId, WateringEvent event) async {
    // Ensure treeId is in the event map
    final map = event.toMap();
    map['treeId'] = treeId;
    await _treesCollection.doc(treeId).collection('regs').add(map);
  }

  Future<void> updateWateringEvent(String treeId, WateringEvent event) async {
    // Ensure treeId is in the event map
    final map = event.toMap();
    map['treeId'] = treeId;
    await _treesCollection
        .doc(treeId)
        .collection('regs')
        .doc(event.id)
        .update(map);
  }

  Future<void> deleteWateringEvent(String treeId, String eventId) async {
    await _treesCollection.doc(treeId).collection('regs').doc(eventId).delete();
  }

  // --- Global Watering Vision ---

  Stream<List<WateringEvent>> getGlobalWateringEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? treeId,
    int days = 7, // Fallback if no dates provided
  }) {
    Query query = FirebaseFirestore.instance.collectionGroup('regs');

    if (startDate != null && endDate != null) {
      // Use provided range
      // Important to set start time to 00:00:00 and end time to 23:59:59
      final start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      query = query
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end);
    } else {
      // Fallback to last N days
      final cutoff = DateTime.now().subtract(Duration(days: days));
      query = query.where('date', isGreaterThanOrEqualTo: cutoff);
    }

    if (treeId != null) {
      // NOTE: This might require a Composite Index (treeId + date)
      // The user already knows about index creation requirements.
      // But 'treeId' is a field inside the document data, not always indexed equaly in collection group queries if not explicitly set.
      // Wait, watering events have 'treeId' field inside? Yes.
      query = query.where('treeId', isEqualTo: treeId);
    }

    return query.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return WateringEvent.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // --- Evolution ---

  Stream<List<EvolutionEntry>> getEvolutionStream(String treeId) {
    return _treesCollection
        .doc(treeId)
        .collection('evolucio')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return EvolutionEntry.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addEvolutionEntry(String treeId, EvolutionEntry entry) async {
    await _treesCollection
        .doc(treeId)
        .collection('evolucio')
        .add(entry.toMap());
  }

  Future<String?> uploadEvolutionImage(XFile imageFile, String treeId) async {
    try {
      final ref = _storage.ref().child(
        'evolution_images/$treeId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final bytes = await imageFile.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading evolution image: $e');
      return null;
    }
  }

  // --- AI History ---

  Stream<List<AIAnalysisEntry>> getAIHistoryStream(String treeId) {
    return _treesCollection
        .doc(treeId)
        .collection('historic_ia')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AIAnalysisEntry.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addAIHistoryEntry(String treeId, AIAnalysisEntry entry) async {
    await _treesCollection
        .doc(treeId)
        .collection('historic_ia')
        .add(entry.toMap());
  }

  Future<void> deleteAIHistoryEntry(String treeId, String entryId) async {
    await _treesCollection
        .doc(treeId)
        .collection('historic_ia')
        .doc(entryId)
        .delete();
  }
}
