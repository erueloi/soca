import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/watering_event.dart';
import '../../domain/entities/evolution_entry.dart';
import '../../domain/entities/ai_analysis_entry.dart';
import '../../domain/entities/growth_entry.dart';

class TreesRepository {
  final CollectionReference _treesCollection = FirebaseFirestore.instance
      .collection('trees');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String? fincaId;

  TreesRepository({this.fincaId});

  Stream<List<Tree>> getTreesStream() {
    debugPrint('TreesRepository: getTreesStream called. FincaId: $fincaId');
    if (fincaId == null) {
      debugPrint('TreesRepository: FincaId is null, returning empty list.');
      return Stream.value([]);
    }

    return _treesCollection
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('plantingDate', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: Got snapshot with ${snapshot.docs.length} docs.',
          );
          return snapshot.docs.map((doc) {
            return Tree.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        })
        .handleError((error) {
          debugPrint('TreesRepository: Error in getTreesStream: $error');
          return <Tree>[];
        });
  }

  Future<void> addTree(Tree tree) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final treeToSave = tree.copyWith(fincaId: fincaId);
    await _treesCollection.doc(tree.id).set(treeToSave.toMap());
  }

  Future<void> updateTree(Tree tree) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final treeToSave = tree.copyWith(fincaId: fincaId);
    await _treesCollection.doc(tree.id).update(treeToSave.toMap());
  }

  Future<void> deleteTree(String treeId) async {
    await _treesCollection.doc(treeId).delete();
  }

  Future<String?> uploadTreeImage(XFile imageFile, String treeId) async {
    try {
      final ref = _storage.ref().child(
        'tree_images/$treeId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(imageFile.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading tree image: $e');
      return null;
    }
  }

  Future<void> addTimelineEvent(String treeId, TreeEvent event) async {
    await _treesCollection.doc(treeId).update({
      'timeline': FieldValue.arrayUnion([event.toMap()]),
    });
  }

  Stream<List<WateringEvent>> getWateringEventsStream(String treeId) {
    debugPrint(
      'TreesRepository: getWateringEventsStream called for $treeId. FincaId: $fincaId',
    );
    if (fincaId == null) return Stream.value([]);

    return _treesCollection
        .doc(treeId)
        .collection('regs')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: Watering snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return WateringEvent.fromMap(doc.data(), doc.id);
          }).toList();
        })
        .handleError((e) {
          debugPrint('TreesRepository: Error in watering stream: $e');
          return <WateringEvent>[];
        });
  }

  Future<void> addWateringEvent(String treeId, WateringEvent event) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final map = event.toMap();
    map['treeId'] = treeId;
    map['fincaId'] = fincaId;
    await _treesCollection.doc(treeId).collection('regs').add(map);
  }

  Future<void> updateWateringEvent(String treeId, WateringEvent event) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final map = event.toMap();
    map['treeId'] = treeId;
    map['fincaId'] = fincaId;
    await _treesCollection
        .doc(treeId)
        .collection('regs')
        .doc(event.id)
        .update(map);
  }

  Future<void> deleteWateringEvent(String treeId, String eventId) async {
    await _treesCollection.doc(treeId).collection('regs').doc(eventId).delete();
  }

  Stream<List<WateringEvent>> getGlobalWateringEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? treeId,
    int days = 7,
  }) {
    if (fincaId == null) return Stream.value([]);

    Query query = FirebaseFirestore.instance.collectionGroup('regs');
    query = query.where('fincaId', isEqualTo: fincaId);

    if (startDate != null && endDate != null) {
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
      final cutoff = DateTime.now().subtract(Duration(days: days));
      query = query.where('date', isGreaterThanOrEqualTo: cutoff);
    }

    if (treeId != null) {
      query = query.where('treeId', isEqualTo: treeId);
    }

    return query
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: Global Watering snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return WateringEvent.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        })
        .handleError((e) {
          debugPrint('TreesRepository: Error in global watering stream: $e');
          return <WateringEvent>[];
        });
  }

  Stream<List<EvolutionEntry>> getEvolutionStream(String treeId) {
    if (fincaId == null) return Stream.value([]);

    return _treesCollection
        .doc(treeId)
        .collection('evolucio')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: Evolution snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return EvolutionEntry.fromMap(doc.data(), doc.id);
          }).toList();
        })
        .handleError((e) {
          debugPrint('TreesRepository: Error in evolution stream: $e');
          return <EvolutionEntry>[];
        });
  }

  Future<void> addEvolutionEntry(String treeId, EvolutionEntry entry) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final map = entry.toMap();
    map['fincaId'] = fincaId;
    await _treesCollection.doc(treeId).collection('evolucio').add(map);
  }

  Future<String?> uploadEvolutionImage(XFile imageFile, String treeId) async {
    try {
      debugPrint('Repo: uploadEvolutionImage started for tree $treeId');
      final ref = _storage.ref().child(
        'evolution_images/$treeId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(imageFile.path);
        if (!await file.exists()) {
          debugPrint('Repo ERROR: File does not exist at path!');
        }
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading evolution image: $e');
      return null;
    }
  }

  Stream<List<GrowthEntry>> getGrowthEntriesStream(String treeId) {
    if (fincaId == null) return Stream.value([]);

    return _treesCollection
        .doc(treeId)
        .collection('seguiment')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: Growth snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return GrowthEntry.fromMap(doc.data(), doc.id);
          }).toList();
        })
        .handleError((e) {
          debugPrint('TreesRepository: Error in growth stream: $e');
          return <GrowthEntry>[];
        });
  }

  Future<void> addGrowthEntry(String treeId, GrowthEntry entry) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final map = entry.toMap();
    map['fincaId'] = fincaId;

    await _treesCollection.doc(treeId).collection('seguiment').add(map);

    final Map<String, dynamic> updates = {};
    if (entry.height > 0) updates['height'] = entry.height;
    if (entry.trunkDiameter > 0) updates['trunkDiameter'] = entry.trunkDiameter;

    if (updates.isNotEmpty) {
      await _treesCollection.doc(treeId).update(updates);
    }
  }

  Stream<List<AIAnalysisEntry>> getAIHistoryStream(String treeId) {
    if (fincaId == null) return Stream.value([]);

    return _treesCollection
        .doc(treeId)
        .collection('historic_ia')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TreesRepository: AI History snapshot: ${snapshot.docs.length} docs',
          );
          return snapshot.docs.map((doc) {
            return AIAnalysisEntry.fromMap(doc.data(), doc.id);
          }).toList();
        })
        .handleError((e) {
          debugPrint('TreesRepository: Error in AI history stream: $e');
          return <AIAnalysisEntry>[];
        });
  }

  Future<void> addAIHistoryEntry(String treeId, AIAnalysisEntry entry) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final map = entry.toMap();
    map['fincaId'] = fincaId;
    await _treesCollection.doc(treeId).collection('historic_ia').add(map);
  }

  Future<void> deleteAIHistoryEntry(String treeId, String entryId) async {
    await _treesCollection
        .doc(treeId)
        .collection('historic_ia')
        .doc(entryId)
        .delete();
  }

  Future<String> generateTreeReference(String speciesPrefix) async {
    if (speciesPrefix.isEmpty) return '???-001';
    if (fincaId == null) return '???-001';

    final start = '$speciesPrefix-000';
    final end = '$speciesPrefix-999';

    final querySnapshot = await _treesCollection
        .where('fincaId', isEqualTo: fincaId)
        .where('reference', isGreaterThanOrEqualTo: start)
        .where('reference', isLessThanOrEqualTo: end)
        .get();

    final count = querySnapshot.docs.length;
    final nextNumber = count + 1;

    return '$speciesPrefix-${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<Map<String, dynamic>> migrateTreeReferences() async {
    if (fincaId == null) return {'error': 'No fincaId'};

    final stats = {'updated': 0, 'details': <String>[]};

    final snapshot = await _treesCollection
        .where('fincaId', isEqualTo: fincaId)
        .get();

    final allTrees = snapshot.docs
        .map((doc) => Tree.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final treesToMigrate = allTrees
        .where((t) => t.reference == null || t.reference!.isEmpty)
        .toList();

    final grouped = <String, List<Tree>>{};
    for (var tree in treesToMigrate) {
      final key = tree.speciesId ?? tree.commonName;
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(tree);
    }

    final batch = FirebaseFirestore.instance.batch();

    for (var entry in grouped.entries) {
      final groupTrees = entry.value;
      groupTrees.sort((a, b) => a.plantingDate.compareTo(b.plantingDate));

      String prefix = 'UNK';
      if (groupTrees.isNotEmpty) {
        final first = groupTrees.first;
        final name = first.commonName.toUpperCase().replaceAll(
          RegExp(r'[^A-Z]'),
          '',
        );
        prefix = name.length >= 3
            ? name.substring(0, 3)
            : name.padRight(3, 'X');
      }

      final existingWithPrefix = allTrees
          .where(
            (t) => t.reference != null && t.reference!.startsWith('$prefix-'),
          )
          .length;
      int nextSeq = existingWithPrefix + 1;

      for (var tree in groupTrees) {
        final ref = '$prefix-${nextSeq.toString().padLeft(3, '0')}';
        batch.update(_treesCollection.doc(tree.id), {'reference': ref});
        nextSeq++;
        stats['updated'] = (stats['updated'] as int) + 1;
        (stats['details'] as List<String>).add('${tree.commonName} -> $ref');
      }
    }

    await batch.commit();
    return stats;
  }

  Future<int> migrateEvolutionToGrowth() async {
    if (fincaId == null) return 0;

    final trees = await _treesCollection
        .where('fincaId', isEqualTo: fincaId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    int itemsMigrated = 0;

    for (var treeDoc in trees.docs) {
      final existingMigrations = await treeDoc.reference
          .collection('seguiment')
          .where('fincaId', isEqualTo: fincaId)
          .where('estat_salut', isEqualTo: 'Migrat')
          .get();

      for (var doc in existingMigrations.docs) {
        batch.delete(doc.reference);
        count++;
      }

      final evolutionSnapshot = await treeDoc.reference
          .collection('evolucio')
          .where('fincaId', isEqualTo: fincaId)
          .get();

      for (var evoDoc in evolutionSnapshot.docs) {
        final data = evoDoc.data();
        final newEntryRef = treeDoc.reference
            .collection('seguiment')
            .doc('MIG_${evoDoc.id}');

        batch.set(newEntryRef, {
          'date': data['date'],
          'photoUrl': data['photoUrl'],
          'alcada': 0.0,
          'diametre_tronc': 0.0,
          'estat_salut': 'Migrat',
          'observacions': data['note'] ?? '',
          'fincaId': fincaId,
        });

        itemsMigrated++;
        count++;

        if (count >= 400) {
          await batch.commit();
          count = 0;
        }
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    return itemsMigrated;
  }

  Future<void> deleteGrowthEntry(String treeId, String entryId) async {
    await _treesCollection
        .doc(treeId)
        .collection('seguiment')
        .doc(entryId)
        .delete();
  }
}
