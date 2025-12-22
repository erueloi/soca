import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore;

  FirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection References
  // Add getters for your collections here, e.g.:
  // CollectionReference get usersCollection => _firestore.collection('users');

  /// Generic method to add a document to a collection
  Future<void> addDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collectionPath).add(data);
  }

  /// Generic method to get a stream of a collection
  /// Optimized for Blaze Plan: Using Cache First can save reads,
  /// but be careful with stale data if not managed correctly.
  /// Current approach: Default behavior (syncs with server).
  Stream<QuerySnapshot> getCollectionStream(String collectionPath) {
    return _firestore.collection(collectionPath).snapshots();
  }
}
