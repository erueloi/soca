import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/resources_view.dart';
import '../../../contacts/presentation/widgets/contacts_view.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../directory/presentation/providers/directory_provider.dart';

import '../widgets/resource_form_dialog.dart';

class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    setState(() {}); // Rebuild to update FAB
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addNewItem() {
    if (_tabController.index == 0) {
      // Add Contact
      _showContactDialog(context);
    } else {
      // Add Resource
      showResourceFormDialog(context, ref);
    }
  }

  Future<void> _showContactDialog(
    BuildContext context, [
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

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingContact == null ? 'Nou Contacte' : 'Editar Contacte',
        ),
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
            onPressed: () {
              final contact = Contact(
                id:
                    existingContact?.id ??
                    '', // ID handled by repo if empty/new logic needed?
                // Actually Repo.add auto-generates ID. So we need to handle that.
                // If repo uses .add, ID in object is ignored.
                name: nameController.text,
                role: roleController.text,
                phone: phoneController.text,
                email: emailController.text,
              );

              final repo = ref.read(contactsRepositoryProvider);
              if (existingContact == null) {
                repo.addContact(contact);
              } else {
                repo.updateContact(contact);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String _searchQuery = '';
  bool _isSearching = false;

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cercar...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Directori de la Finca'),
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, '/config');
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'CONTACTES', icon: Icon(Icons.people)),
            Tab(text: 'RECURSOS', icon: Icon(Icons.folder)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ContactsView(
            searchQuery: _searchQuery,
            onEdit: (c) => _showContactDialog(context, c),
          ),
          ResourcesView(
            searchQuery: _searchQuery,
            onEdit: (r) => showResourceFormDialog(context, ref, r),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewItem,
        icon: Icon(
          _tabController.index == 0 ? Icons.person_add : Icons.note_add,
        ),
        label: Text(_tabController.index == 0 ? 'Nou Contacte' : 'Nou Recurs'),
      ),
    );
  }
}
