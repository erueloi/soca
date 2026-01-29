import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/contact.dart';
import '../contacts_data.dart';

class ContactsRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'contacts',
  );
  final String? fincaId;

  ContactsRepository({this.fincaId});

  Stream<List<Contact>> getContactsStream() {
    if (fincaId == null) return Stream.value([]);

    return _collection.where('fincaId', isEqualTo: fincaId).snapshots().asyncMap((
      snapshot,
    ) async {
      if (snapshot.docs.isEmpty) {
        // Perform migration if list is empty
        await _migrateInitialContacts();
        // The stream will emit again due to the writes, so we can return empty for now
        // or return the static data directly to be faster
        return ContactsData.allContacts;
      }

      return snapshot.docs.map((doc) {
        return Contact.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> _migrateInitialContacts() async {
    if (fincaId == null) return;

    debugPrint(
      'ContactsRepository: Migrating initial contacts for finca $fincaId',
    );
    // Only migrate if truly empty to avoid duplicates on race conditions
    // (though logic above handles the check, safe to double check or just add)

    final batch = FirebaseFirestore.instance.batch();

    for (final contact in ContactsData.allContacts) {
      final docRef = _collection.doc(); // Auto-ID
      final data = contact.toMap();
      data['fincaId'] = fincaId;
      batch.set(docRef, data);
    }

    await batch.commit();
  }

  Future<void> addContact(Contact contact) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final data = contact.toMap();
    data['fincaId'] = fincaId;

    await _collection.add(data);
  }

  Future<void> updateContact(Contact contact) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final data = contact.toMap();
    data['fincaId'] = fincaId;

    await _collection.doc(contact.id).update(data);
  }

  Future<void> deleteContact(String id) async {
    await _collection.doc(id).delete();
  }
}
