import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/resource.dart';
import '../../presentation/providers/directory_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

Future<void> showResourceFormDialog(
  BuildContext context,
  WidgetRef ref, [
  Resource? existingResource,
  String? prefilledUrl,
]) async {
  final titleController = TextEditingController(
    text: existingResource?.title ?? '',
  );
  final urlController = TextEditingController(
    text: existingResource?.url ?? prefilledUrl ?? '',
  );

  // We need config to populate dropdowns
  // Since this is an async dialog trigger, we usually have the config loaded.
  // We'll peek at the current value.
  final configAsync = ref.read(farmConfigStreamProvider);
  final config = configAsync.value;

  if (config == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuració no carregada')));
    return;
  }

  // Defaults
  String selectedTypeId = existingResource?.typeId ?? 'link';
  String selectedCategoryId = existingResource?.categoryId ?? 'materials';

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
                                color: Color(int.parse(t.colorHex, radix: 16)),
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
                                color: Color(int.parse(c.colorHex, radix: 16)),
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
