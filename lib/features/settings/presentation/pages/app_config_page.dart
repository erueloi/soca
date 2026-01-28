import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../domain/entities/farm_config.dart';
import '../providers/settings_provider.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';

class AppConfigPage extends ConsumerStatefulWidget {
  const AppConfigPage({super.key});

  @override
  ConsumerState<AppConfigPage> createState() => _AppConfigPageState();
}

class _AppConfigPageState extends ConsumerState<AppConfigPage> {
  // Phases
  late List<TaskPhase> _phases;

  // Authorized Emails
  late List<String> _authorizedEmails;
  final TextEditingController _emailController = TextEditingController();

  // Categories
  late List<ExpenseCategory> _categories;

  bool _isInit = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final config = ref.watch(farmConfigStreamProvider).value;
      if (config != null) {
        _phases = List.from(config.taskPhases);
        _categories = List.from(config.expenseCategories);
        _authorizedEmails = List.from(config.authorizedEmails);
        _isInit = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(farmConfigStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuració de l\'Aplicació'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving || (configAsync.value?.fincaId == null)
                ? null
                : _saveConfig,
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (config) {
          if (!_isInit) {
            // In case didChangeDependencies didn't catch it or for first build
            _phases = List.from(config.taskPhases);
            _categories = List.from(config.expenseCategories);
            _authorizedEmails = List.from(config.authorizedEmails);
            _isInit = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle('Emails Autoritzats (Seguretat)'),
              const Text(
                'Llista d\'emails que tenen accés a aquesta finca. Afegeix el teu i el de la teva parella.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              _buildAuthorizedEmailsList(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildSectionTitle('Fases de Tasques'),
              const Text(
                'Etiquetes per organitzar el flux de treball de les tasques.',
              ),
              const SizedBox(height: 8),
              _buildPhasesList(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildSectionTitle('Categories de Despesa'),
              const Text(
                'Categories per classificar els costos de les tasques.',
              ),
              const SizedBox(height: 8),
              _buildCategoriesList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // --- AUTHORIZED EMAILS ---

  Widget _buildAuthorizedEmailsList() {
    return Column(
      children: [
        if (_authorizedEmails.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '⚠️ Cap email autoritzat! Afegeix el teu per no perdre accés.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ..._authorizedEmails.asMap().entries.map((entry) {
          final index = entry.key;
          final email = entry.value;
          return ListTile(
            key: ValueKey('email_$index'),
            dense: true,
            leading: const Icon(Icons.email, size: 20),
            title: Text(email),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () =>
                  setState(() => _authorizedEmails.removeAt(index)),
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Nou Email',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.add),
                ),
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _addEmail(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle, size: 32),
              color: Colors.green,
              onPressed: _addEmail,
            ),
          ],
        ),
      ],
    );
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      if (!_authorizedEmails.contains(email)) {
        setState(() {
          _authorizedEmails.add(email);
          _emailController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aquest email ja està a la llista.')),
        );
      }
    } else if (email.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Format d\'email invàlid.')));
    }
  }

  // --- PHASES ---

  Widget _buildPhasesList() {
    return Column(
      children: [
        if (_phases.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No hi ha fases definides.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = _phases.removeAt(oldIndex);
              _phases.insert(newIndex, item);
            });
          },
          children: [
            for (int i = 0; i < _phases.length; i++)
              ListTile(
                key: ValueKey('phase_${_phases[i].name}'),
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Color(
                    int.parse(_phases[i].colorHex, radix: 16),
                  ),
                  radius: 16,
                  child: Icon(
                    IconData(_phases[i].iconCode, fontFamily: 'MaterialIcons'),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(_phases[i].name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editPhase(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePhase(i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.drag_handle, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addNewPhase,
          icon: const Icon(Icons.add),
          label: const Text('Afegir Nova Fase'),
        ),
      ],
    );
  }

  void _addNewPhase() {
    _showPhaseDialog();
  }

  void _editPhase(int index) {
    _showPhaseDialog(index: index, existing: _phases[index]);
  }

  Future<void> _deletePhase(int index) async {
    final phaseName = _phases[index].name;
    final repo = ref.read(tasksRepositoryProvider);
    // Integrity Check
    try {
      final tasks = await repo.getTasksByPhase(phaseName);
      if (tasks.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Fase en ús'),
            content: Text(
              'Aquesta fase s\'està utilitzant en ${tasks.length} tasques.\n'
              'Si l\'esborres, aquestes tasques mantindran el nom "$phaseName" però perdran la icona i configuració.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel·lar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _phases.removeAt(index));
                },
                child: const Text('Esborrar igualment'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      // If we can't check, just warn generically
      debugPrint('Error checking tasks usage: $e');
    }

    setState(() => _phases.removeAt(index));
  }

  Future<void> _showPhaseDialog({int? index, TaskPhase? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    Color currentColor = existing != null
        ? Color(int.parse(existing.colorHex, radix: 16))
        : Colors.blue;
    int currentIconCode = existing?.iconCode ?? Icons.label.codePoint;

    final bool isEditing = existing != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Fase' : 'Nova Fase'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Color: '),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Triar Color'),
                              content: SingleChildScrollView(
                                child: BlockPicker(
                                  pickerColor: currentColor,
                                  onColorChanged: (color) {
                                    setStateDialog(() => currentColor = color);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(backgroundColor: currentColor),
                      ),
                      const Spacer(),
                      const Text('Icona: '),
                      IconButton(
                        icon: Icon(
                          IconData(
                            currentIconCode,
                            fontFamily: 'MaterialIcons',
                          ),
                        ),
                        onPressed: () async {
                          final icon = await _showIconPicker(context);
                          if (icon != null) {
                            setStateDialog(
                              () => currentIconCode = icon.codePoint,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;

                  final newPhase = TaskPhase(
                    name: nameCtrl.text.trim(),
                    colorHex: currentColor
                        .toARGB32()
                        .toRadixString(16)
                        .padLeft(8, '0')
                        .toUpperCase(),
                    iconCode: currentIconCode,
                  );

                  if (isEditing) {
                    setState(() => _phases[index!] = newPhase);
                  } else {
                    setState(() => _phases.add(newPhase));
                  }
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- CATEGORIES ---

  Widget _buildCategoriesList() {
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          buildDefaultDragHandles: false, // Prevent duplicate handles
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = _categories.removeAt(oldIndex);
              _categories.insert(newIndex, item);
            });
          },
          children: [
            for (int i = 0; i < _categories.length; i++)
              Card(
                key: ValueKey(_categories[i].id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      int.parse(_categories[i].colorHex, radix: 16),
                    ),
                    child: Icon(
                      IconData(
                        _categories[i].iconCode,
                        fontFamily: 'MaterialIcons',
                      ),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(_categories[i].name),
                  subtitle: Text('ID: ${_categories[i].id}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editCategory(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(i),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addNewCategory,
          icon: const Icon(Icons.add),
          label: const Text('Afegir Nova Categoria'),
        ),
      ],
    );
  }

  void _addNewCategory() {
    _showCategoryDialog();
  }

  void _editCategory(int index) {
    _showCategoryDialog(index: index, existing: _categories[index]);
  }

  Future<void> _deleteCategory(int index) async {
    if (_categories[index].id == 'material') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No es pot eliminar la categoria "material".'),
        ),
      );
      return;
    }

    final categoryId = _categories[index].id;
    final repo = ref.read(tasksRepositoryProvider);
    // Integrity Check
    try {
      final taskCount = await repo.countTasksByCategory(categoryId);
      if (taskCount > 0) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Categoria en ús'),
            content: Text(
              'Aquesta categoria s\'utilitza en $taskCount tasques.\n'
              'Si l\'esborres, aquestes despeses poden quedar sense categoria.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel·lar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _categories.removeAt(index));
                },
                child: const Text('Esborrar igualment'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      // If verification fails, allow standard delete with warning
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Categoria?'),
        content: const Text('Segur que vols eliminar aquesta categoria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _categories.removeAt(index));
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog({
    int? index,
    ExpenseCategory? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    Color currentColor = existing != null
        ? Color(int.parse(existing.colorHex, radix: 16))
        : Colors.blue;
    int currentIconCode = existing?.iconCode ?? Icons.category.codePoint;

    // Only allow editing ID for NEW categories to prevent breaking links
    final bool isEditing = existing != null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Categoria' : 'Nova Categoria'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID (únic, minúscules)',
                      hintText: 'ex: material_obra',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isEditing, // Lock ID if editing
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Color: '),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Triar Color'),
                              content: SingleChildScrollView(
                                child: BlockPicker(
                                  pickerColor: currentColor,
                                  onColorChanged: (color) {
                                    setStateDialog(() => currentColor = color);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(backgroundColor: currentColor),
                      ),
                      const Spacer(),
                      const Text('Icona: '),
                      IconButton(
                        icon: Icon(
                          IconData(
                            currentIconCode,
                            fontFamily: 'MaterialIcons',
                          ),
                        ),
                        onPressed: () async {
                          // Simple Icon Picker
                          final icon = await _showIconPicker(context);
                          if (icon != null) {
                            setStateDialog(
                              () => currentIconCode = icon.codePoint,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || idCtrl.text.isEmpty) return;

                  final newCat = ExpenseCategory(
                    id: idCtrl.text.trim().toLowerCase(),
                    name: nameCtrl.text.trim(),
                    colorHex: currentColor
                        .toARGB32()
                        .toRadixString(16)
                        .padLeft(8, '0')
                        .toUpperCase(), // Ensure ARGB
                    iconCode: currentIconCode,
                  );

                  if (isEditing) {
                    setState(() => _categories[index!] = newCat);
                  } else {
                    // Check ID uniqueness
                    if (_categories.any((c) => c.id == newCat.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ja existeix una categoria amb aquest ID.',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => _categories.add(newCat));
                  }
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<IconData?> _showIconPicker(BuildContext context) async {
    // Small set of common icons
    final icons = [
      Icons.category,
      Icons.construction,
      Icons.build,
      Icons.design_services,
      Icons.more_horiz,
      Icons.agriculture,
      Icons.local_florist,
      Icons.water,
      Icons.wb_sunny,
      Icons.grass,
      Icons.pets,
      Icons.science,
      Icons.work,
      Icons.engineering,
      Icons.handyman,
      Icons.hardware,
      Icons.plumbing,
      Icons.electric_bolt,
      Icons.format_paint,
      Icons.brush,
      Icons.shopping_cart,
      Icons.calendar_today,
      Icons.warning,
      Icons.flag,
      Icons.label,
    ];

    return await showDialog<IconData>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Triar Icona'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: icons
              .map(
                (icon) => IconButton(
                  icon: Icon(icon),
                  onPressed: () => Navigator.pop(context, icon),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      // We need current config to update only specific fields?
      // Actually updateFarmConfig usually replaces/merges.
      // Let's get current config first to copyWith
      final currentConfig = ref.read(farmConfigStreamProvider).value;
      if (currentConfig != null) {
        final newConfig = currentConfig.copyWith(
          taskPhases: _phases,
          expenseCategories: _categories,
          authorizedEmails: _authorizedEmails,
        );
        await repo.saveFarmConfig(newConfig);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuració guardada correctament! ✅'),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error guardant: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
