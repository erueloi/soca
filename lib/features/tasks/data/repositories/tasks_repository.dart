import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import '../../domain/entities/task.dart';
import '../../domain/entities/bucket.dart';

class TasksRepository {
  final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('tasks');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Task>> getTasksStream() {
    return _tasksCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addTask(Task task) async {
    // Start with the ID provided in the Task object.
    await _tasksCollection.doc(task.id).set(task.toMap());
  }

  Future<void> updateTask(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
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
      print('Error uploading image: $e');
      return null;
    }
  }

  // Buckets Management
  Stream<List<Bucket>> getBucketsStream() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc('config')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            // Return default defaults if not exists
            return [
              const Bucket(name: 'Valla exterior'),
              const Bucket(name: 'Sala d\'estar'),
              const Bucket(name: 'Aigua'),
              const Bucket(name: 'Arquitectura/Planols'),
              const Bucket(name: 'Documentació'),
              const Bucket(name: 'Reforestació'),
            ];
          }
          final data = snapshot.data() as Map<String, dynamic>;
          final List<dynamic> bucketMaps = data['buckets'] ?? [];
          if (bucketMaps.isEmpty) {
            return [
              const Bucket(name: 'Valla exterior'),
              const Bucket(name: 'Sala d\'estar'),
              const Bucket(name: 'Aigua'),
              const Bucket(name: 'Arquitectura/Planols'),
              const Bucket(name: 'Documentació'),
              const Bucket(name: 'Reforestació'),
            ];
          }
          return bucketMaps.map((m) => Bucket.fromMap(m)).toList();
        });
  }

  Future<void> saveBuckets(List<Bucket> buckets) async {
    await FirebaseFirestore.instance.collection('settings').doc('config').set({
      'buckets': buckets.map((b) => b.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> renameBucket(String oldName, String newName) async {
    if (oldName == newName) return;

    // 1. Update all tasks with the old bucket name
    final batch = FirebaseFirestore.instance.batch();
    final tasksSnapshot = await _tasksCollection
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
