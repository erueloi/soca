import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/resources_repository.dart';
import '../../../contacts/data/repositories/contacts_repository.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../domain/entities/resource.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final configAsync = ref.watch(farmConfigStreamProvider);
  final fincaId = configAsync.value?.fincaId;
  return ContactsRepository(fincaId: fincaId);
});

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  final configAsync = ref.watch(farmConfigStreamProvider);
  final fincaId = configAsync.value?.fincaId;
  return ResourcesRepository(fincaId: fincaId);
});

final contactsStreamProvider = StreamProvider<List<Contact>>((ref) {
  final repository = ref.watch(contactsRepositoryProvider);
  return repository.getContactsStream();
});

final resourcesStreamProvider = StreamProvider<List<Resource>>((ref) {
  final repository = ref.watch(resourcesRepositoryProvider);
  return repository.getResourcesStream();
});
