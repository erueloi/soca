import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/resource.dart';

class ResourcesRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'resources',
  );
  final String? fincaId;

  ResourcesRepository({this.fincaId});

  Stream<List<Resource>> getResourcesStream() {
    if (fincaId == null) return Stream.value([]);

    return _collection
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          // ignore: avoid_print
          print('Resources Query Error: $error');
          throw error;
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Resource.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        });
  }

  Future<void> addResource(Resource resource) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final data = resource.toMap();
    data['fincaId'] = fincaId;

    await _collection.add(data);
  }

  Future<void> updateResource(Resource resource) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final data = resource.toMap();
    data['fincaId'] = fincaId;

    await _collection.doc(resource.id).update(data);
  }

  Future<void> deleteResource(String id) async {
    await _collection.doc(id).delete();
  }
}
