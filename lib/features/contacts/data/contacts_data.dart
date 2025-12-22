import '../domain/entities/contact.dart';

class ContactsData {
  static const List<Contact> allContacts = [
    Contact(
      id: 'c1',
      name: 'Rosa',
      role: 'Arquitecta',
      phone: '600123456',
      email: 'rosa@arquimail.com',
    ),
    Contact(
      id: 'c2',
      name: 'Jordi',
      role: 'Paleta',
      phone: '611223344',
      email: 'jordi.construccions@obra.cat',
    ),
    Contact(
      id: 'c3',
      name: 'Claudi',
      role: 'Lampista/Aigua',
      phone: '622334455',
      email: 'claudi.aigua@inst.com',
    ),
    Contact(
      id: 'c4',
      name: 'Jaume',
      role: 'Jardiner',
      phone: '633445566',
      email: 'jaume.trees@jardi.com',
    ),
    Contact(
      id: 'c5',
      name: 'Fèlix',
      role: 'Proveïdor Material',
      phone: '644556677',
      email: 'felix@materials.com',
    ),
  ];

  static Contact? getById(String id) {
    try {
      return allContacts.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
