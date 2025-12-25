import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/tree.dart';

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
}
