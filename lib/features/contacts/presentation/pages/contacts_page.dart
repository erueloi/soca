import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/contacts_data.dart';
import '../../domain/entities/contact.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Basic Whatsapp link, cleaning the number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final Uri launchUri = Uri.parse('https://wa.me/34$cleanNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directori de la Finca')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ContactsData.allContacts.length,
        separatorBuilder: (ctx, i) => const Divider(),
        itemBuilder: (context, index) {
          final contact = ContactsData.allContacts[index];
          return _ContactTile(
            contact: contact,
            onCall: () => _makePhoneCall(contact.phone),
            onWhatsApp: () => _openWhatsApp(contact.phone),
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _ContactTile({
    required this.contact,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Text(contact.name.substring(0, 1)),
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
            onPressed: onCall,
            tooltip: 'Trucar',
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green),
            onPressed: onWhatsApp,
            tooltip: 'WhatsApp',
          ),
        ],
      ),
    );
  }
}
