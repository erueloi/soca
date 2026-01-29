import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/resources_view.dart';
import '../../../contacts/presentation/widgets/contacts_view.dart';
import '../../domain/entities/resource.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../directory/presentation/providers/directory_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

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
      _showResourceDialog(context);
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

  Future<void> _showResourceDialog(
    BuildContext context, [
    Resource? existingResource,
  ]) async {
    final titleController = TextEditingController(
      text: existingResource?.title ?? '',
    );
    final urlController = TextEditingController(
      text: existingResource?.url ?? '',
    );
    // Defaults from config (we'll fetch inside)
    String selectedTypeId = existingResource?.typeId ?? 'link';
    String selectedCategoryId = existingResource?.categoryId ?? 'materials';

    // We need config to populate dropdowns
    final configAsync = ref.read(farmConfigStreamProvider);
    // Since this is an async dialog, we ideally assume config is loaded or we fetch it.
    // Provider is stream, but we likely have value in cache if page is shown.
    final config = configAsync.value;

    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuració no carregada')),
      );
      return;
    }

    // validate if existing IDs still exist in config, else default
    if (!config.resourceTypes.any((t) => t.id == selectedTypeId)) {
      selectedTypeId = config.resourceTypes.firstOrNull?.id ?? 'other';
    }
    if (!config.resourceCategories.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = config.resourceCategories.firstOrNull?.id ?? 'other';
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existingResource == null ? 'Nou Recurs' : 'Editar Recurs',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Títol'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTypeId,
                    decoration: const InputDecoration(labelText: 'Tipus'),
                    items: config.resourceTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Row(
                              children: [
                                Icon(
                                  IconData(
                                    t.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  size: 16,
                                  color: Color(
                                    int.parse(t.colorHex, radix: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(t.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedTypeId = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: config.resourceCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(
                                  IconData(
                                    c.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  size: 16,
                                  color: Color(
                                    int.parse(c.colorHex, radix: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCategoryId = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL / Enllaç',
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
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
                  final resource = Resource(
                    id: existingResource?.id ?? '',
                    title: titleController.text,
                    typeId: selectedTypeId,
                    url: urlController.text,
                    categoryId: selectedCategoryId,
                    createdAt: existingResource?.createdAt ?? DateTime.now(),
                  );

                  final repo = ref.read(resourcesRepositoryProvider);
                  if (existingResource == null) {
                    repo.addResource(resource);
                  } else {
                    repo.updateResource(resource);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
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
            onEdit: (r) => _showResourceDialog(context, r),
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
