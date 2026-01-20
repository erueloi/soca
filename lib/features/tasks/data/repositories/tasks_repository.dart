import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import '../../domain/entities/task.dart';
import '../../domain/entities/bucket.dart';

class TasksRepository {
  final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('tasks');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String? fincaId;

  TasksRepository({this.fincaId});

  Stream<List<Task>> getTasksStream() {
    debugPrint('TasksRepository: getTasksStream called. FincaId: $fincaId');
    if (fincaId == null) {
      debugPrint('TasksRepository: FincaId is null, returning empty list.');
      return Stream.value([]);
    }

    return _tasksCollection
        .where('fincaId', isEqualTo: fincaId)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'TasksRepository: Got snapshot with ${snapshot.docs.length} docs.',
          );
          return snapshot.docs.map((doc) {
            return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        });
  }

  Future<void> addTask(Task task) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final taskToSave = task.copyWith(fincaId: fincaId);
    // Start with the ID provided in the Task object.
    await _tasksCollection.doc(task.id).set(taskToSave.toMap());
  }

  Future<void> updateTask(Task task) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final taskToSave = task.copyWith(fincaId: fincaId);
    await _tasksCollection.doc(task.id).update(taskToSave.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  Future<String?> uploadTaskImage(File imageFile, String taskId) async {
    try {
      final ref = _storage.ref().child(
        'task_images/$taskId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadTask = await ref.putFile(imageFile);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Buckets Management
  Stream<List<Bucket>> getBucketsStream() {
    if (fincaId == null) return Stream.value(_defaultBuckets);

    final farmDoc = FirebaseFirestore.instance
        .collection('finques')
        .doc(fincaId);

    return farmDoc
        .snapshots()
        .asyncMap((snapshot) async {
          // Use asyncMap to allow migration
          if (!snapshot.exists) {
            return _defaultBuckets;
          }

          final data = snapshot.data();
          if (data != null && data.containsKey('buckets')) {
            final List<dynamic> bucketMaps = data['buckets'] ?? [];
            if (bucketMaps.isEmpty) return _defaultBuckets;
            return bucketMaps.map((m) => Bucket.fromMap(m)).toList();
          }

          // --- MIGRATION LOGIC ---
          // If we are here, 'buckets' field is missing in finques/{id}.
          // Check legacy settings/config
          debugPrint('TasksRepository: Migrating buckets for $fincaId...');
          final legacyDoc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('config')
              .get();

          List<Bucket> bucketsToMigrate = _defaultBuckets;

          if (legacyDoc.exists && legacyDoc.data() != null) {
            final legacyData = legacyDoc.data()!;
            if (legacyData.containsKey('buckets')) {
              final List<dynamic> legacyBuckets = legacyData['buckets'];
              bucketsToMigrate = legacyBuckets
                  .map((m) => Bucket.fromMap(m))
                  .toList();
              debugPrint(
                'TasksRepository: Found ${bucketsToMigrate.length} legacy buckets.',
              );
            }
          }

          // Save to new location immediately
          await farmDoc.set({
            'buckets': bucketsToMigrate.map((b) => b.toMap()).toList(),
          }, SetOptions(merge: true));

          return bucketsToMigrate;
        })
        .handleError((e) {
          debugPrint('TasksRepository: Error loading buckets: $e');
          return _defaultBuckets;
        });
  }

  static const _defaultBuckets = [
    Bucket(name: 'Valla exterior'),
    Bucket(name: 'Sala d\'estar'),
    Bucket(name: 'Aigua'),
    Bucket(name: 'Arquitectura/Planols'),
    Bucket(name: 'Documentació'),
    Bucket(name: 'Reforestació'),
  ];

  Future<void> saveBuckets(List<Bucket> buckets) async {
    if (fincaId == null) return;

    await FirebaseFirestore.instance.collection('finques').doc(fincaId).set({
      'buckets': buckets.map((b) => b.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> renameBucket(String oldName, String newName) async {
    if (oldName == newName) return;
    if (fincaId == null) return;

    // 1. Update all tasks with the old bucket name
    final batch = FirebaseFirestore.instance.batch();
    final tasksSnapshot = await _tasksCollection
        .where('fincaId', isEqualTo: fincaId)
        .where('bucket', isEqualTo: oldName)
        .get();

    for (var doc in tasksSnapshot.docs) {
      batch.update(doc.reference, {'bucket': newName});
    }
    await batch.commit();

    // 2. Note: The actual bucket list update in settings should be handled by saveBuckets
    // but typically we want to do both atomically or sequentially.
    // For now, the caller will handle saving the new bucket list.
  }
}
