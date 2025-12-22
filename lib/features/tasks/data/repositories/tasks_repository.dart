import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import '../../domain/entities/task.dart';

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
}
