import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../providers/directory_provider.dart';

Future<Contact?> showContactFormDialog(
  BuildContext context,
  WidgetRef ref, [
  Contact? existingContact,
]) async {
  final nameController = TextEditingController(
    text: existingContact?.name ?? '',
  );
  final roleController = TextEditingController(
    text: existingContact?.role ?? '',
  );
  final phoneController = TextEditingController(
    text: existingContact?.phone ?? '',
  );
  final emailController = TextEditingController(
    text: existingContact?.email ?? '',
  );

  return await showDialog<Contact?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existingContact == null ? 'Nou Contacte' : 'Editar Contacte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: 'Rol / Professió'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Telèfon'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel·lar'),
        ),
        FilledButton(
          onPressed: () async {
            final contact = Contact(
              id: existingContact?.id ?? '',
              name: nameController.text,
              role: roleController.text,
              phone: phoneController.text,
              email: emailController.text,
            );

            final repo = ref.read(contactsRepositoryProvider);
            Contact? savedContact;
            if (existingContact == null) {
              savedContact = await repo.addContact(contact);
            } else {
              await repo.updateContact(contact);
              savedContact = contact;
            }
            if (ctx.mounted) Navigator.pop(ctx, savedContact);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
