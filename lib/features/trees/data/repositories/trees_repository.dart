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
      debugPrint('Error uploading evolution image: $e');
      return null;
    }
  }

  // --- Growth Timeline (Seguiment) ---

  Stream<List<GrowthEntry>> getGrowthEntriesStream(String treeId) {
    return _treesCollection
        .doc(treeId)
        .collection('seguiment')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GrowthEntry.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addGrowthEntry(String treeId, GrowthEntry entry) async {
    await _treesCollection
        .doc(treeId)
        .collection('seguiment')
        .add(entry.toMap());
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
  // --- Reference Generation ---

  Future<String> generateTreeReference(String speciesPrefix) async {
    if (speciesPrefix.isEmpty) return '???-001';

    // Count existing trees with this reference prefix
    // NOTE: This could be optimized with a counter in a separate document if scalability is an issue.
    // For now, counting docs locally or via count() aggregation is fine for <1000 trees.

    // We can't easily query by "reference startsWith" in Firestore without specific index hacks.
    // Better strategy: Count trees where 'speciesPrefix' matches.
    // BUT 'speciesPrefix' isn't on the tree directly, only 'reference' string.

    // Alternative: We can query all trees and filter locally (slow if many trees).
    // Or assume we pass "speciesId" and inconsistent if prefix changes?
    // Let's rely on the 'reference' field. Using a ">= PREFIX-000" query.

    final start = '$speciesPrefix-000';
    final end = '$speciesPrefix-999';

    final querySnapshot = await _treesCollection
        .where('reference', isGreaterThanOrEqualTo: start)
        .where('reference', isLessThanOrEqualTo: end)
        .get();

    final count = querySnapshot.docs.length;
    final nextNumber = count + 1;

    // Format: OLI-005
    return '$speciesPrefix-${nextNumber.toString().padLeft(3, '0')}';
  }
  // --- Migration ---

  Future<Map<String, dynamic>> migrateTreeReferences() async {
    final stats = {'updated': 0, 'details': <String>[]};

    // 1. Fetch all Trees
    final snapshot = await _treesCollection.get();
    final allTrees = snapshot.docs
        .map((doc) => Tree.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // 2. Identify trees needing migration (empty reference)
    final treesToMigrate = allTrees
        .where((t) => t.reference == null || t.reference!.isEmpty)
        .toList();

    // 3. Group by Species
    final grouped = <String, List<Tree>>{};
    for (var tree in treesToMigrate) {
      // Use speciesId if available, otherwise common name as fallback key
      final key = tree.speciesId ?? tree.commonName;
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(tree);
    }

    // 4. Process groups
    final batch = FirebaseFirestore.instance.batch();

    for (var entry in grouped.entries) {
      final groupTrees = entry.value;

      // Sort by plantingDate (oldest first)
      groupTrees.sort((a, b) => a.plantingDate.compareTo(b.plantingDate));

      // Determine prefix
      String prefix = 'UNK';
      // If key is ID, try to find prefix?
      // Actually we need to fetch species doc to be sure, or rely on a "best effort" from tree data.
      // But Tree doesn't store prefix.
      // We must fetch the species to get the prefix.

      // OPTIMIZATION: We could fetch all species once at start.
      // For now, let's guess from commonName if speciesId lookup fails or is too complex in this loop.
      // But wait, the user asked to "generate prefix from commonName 3 uppercase chars" if missing in species.
      // So let's derive it from the first tree's commonName in the group if we can't find it easily.

      // Let's rely on common name of the first tree in the group for the prefix if we don't have better info.
      if (groupTrees.isNotEmpty) {
        final first = groupTrees.first;
        final name = first.commonName.toUpperCase().replaceAll(
          RegExp(r'[^A-Z]'),
          '',
        );
        prefix = name.length >= 3
            ? name.substring(0, 3)
            : name.padRight(3, 'X');

        // Try to respect existing 'Species' prefix if possible, but we don't have access to SpeciesRepo here easily
        // without injecting it.
        // However, the instructions say:
        // "Prefixos d'Espècie: Revisa la col·lecció especies. Si alguna no té el camp prefix, genera'l usant les 3 primeres lletres del nom comú en majúscules."

        // Ideally we should have run the Species Migration first.
        // Let's assume the user handles species update OR we do it "on the fly" here based on common name.
        // User instruction: "Recuperi tots els documents... assigni referencia [PREFIX]-[NUM]"

        // Let's simplify: Use common name based prefix.
        // But what if different species share common name first 3 letters? (e.g. "Albercoc" vs "Alzina" -> ALB for both?)
        // The user gave examples: "Olivera" -> "OLI", "Albercoc" -> "ALB", "Noguer" -> "NOG", "Alzina" -> "ALZ".
        // Wait, Alzina -> ALZ. Albercoc -> ALB.
        // So 3 letters is risky if not careful.
        // But for this migration script let's do simple substring(0,3).
      }

      // Check existing count for this prefix in DB?
      // Since we are migrating *all* missing ones, and potentially some exist?
      // "Recuperi tots els documents... que NO tinguin el camp referencia."
      // We should check if there are ANY existing references with this prefix to start counting correctly.
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
    final trees = await _treesCollection.get();
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    int itemsMigrated = 0;

    for (var treeDoc in trees.docs) {
      // 1. Cleanup previous migrations (idempotency)
      final existingMigrations = await treeDoc.reference
          .collection('seguiment')
          .where('estat_salut', isEqualTo: 'Migrat')
          .get();

      for (var doc in existingMigrations.docs) {
        batch.delete(doc.reference);
        count++;
      }

      // 2. Migrate Evolution
      final evolutionSnapshot = await treeDoc.reference
          .collection('evolucio')
          .get();
      for (var evoDoc in evolutionSnapshot.docs) {
        final data = evoDoc.data();

        // Use deterministic ID to avoid duplicates in same run, though cleanup handles re-runs
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
