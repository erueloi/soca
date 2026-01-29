import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../directory/presentation/providers/directory_provider.dart';
import '../../../contacts/domain/entities/contact.dart';

class ContactsView extends ConsumerWidget {
  final Function(Contact) onEdit;
  final String searchQuery;

  const ContactsView({super.key, required this.onEdit, this.searchQuery = ''});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final Uri launchUri = Uri.parse('https://wa.me/34$cleanNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  void _deleteContact(BuildContext context, WidgetRef ref, Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Contacte?'),
        content: Text('Vols eliminar a ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              ref.read(contactsRepositoryProvider).deleteContact(contact.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Sí, eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsStreamProvider);

    return contactsAsync.when(
      data: (contacts) {
        final filteredContacts = contacts.where((contact) {
          final query = searchQuery.toLowerCase();
          return contact.name.toLowerCase().contains(query) ||
              contact.role.toLowerCase().contains(query);
        }).toList();

        if (filteredContacts.isEmpty) {
          return Center(
            child: Text(
              searchQuery.isEmpty
                  ? 'No hi ha contactes.'
                  : 'No s\'han trobat resultats.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredContacts.length + 1, // +1 for padding at bottom
          separatorBuilder: (ctx, i) => const Divider(),
          itemBuilder: (context, index) {
            if (index == filteredContacts.length) {
              return const SizedBox(height: 80); // Fab padding
            }

            final contact = filteredContacts[index];
            return ListTile(
              onTap: () => onEdit(contact),
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  contact.name.isNotEmpty
                      ? contact.name.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
              title: Text(
                contact.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${contact.role}\n${contact.phone}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _makePhoneCall(contact.phone),
                    tooltip: 'Trucar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.green),
                    onPressed: () => _openWhatsApp(contact.phone),
                    tooltip: 'WhatsApp',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteContact(context, ref, contact);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
