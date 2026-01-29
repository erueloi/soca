import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/resource.dart';
import '../../presentation/providers/directory_provider.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/domain/entities/farm_config.dart';

class ResourcesView extends ConsumerWidget {
  final Function(Resource) onEdit;
  final String searchQuery;

  const ResourcesView({super.key, required this.onEdit, this.searchQuery = ''});

  Future<void> _openResource(Resource resource) async {
    final uri = Uri.tryParse(resource.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Show snackbar or alert
    }
  }

  ResourceTypeConfig _getTypeConfig(FarmConfig config, String typeId) {
    return config.resourceTypes.firstWhere(
      (t) => t.id == typeId,
      orElse: () => ResourceTypeConfig(
        id: 'other',
        name: 'Altre',
        colorHex: 'FF9E9E9E',
        iconCode: Icons.insert_drive_file.codePoint,
      ),
    );
  }

  ResourceCategoryConfig _getCategoryConfig(FarmConfig config, String catId) {
    return config.resourceCategories.firstWhere(
      (c) => c.id == catId,
      orElse: () => ResourceCategoryConfig(
        id: 'other',
        name: 'Altres',
        colorHex: 'FF9E9E9E',
        iconCode: Icons.folder.codePoint,
      ),
    );
  }

  void _deleteResource(BuildContext context, WidgetRef ref, Resource resource) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Recurs?'),
        content: Text('Vols eliminar "${resource.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              ref.read(resourcesRepositoryProvider).deleteResource(resource.id);
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
    final resourcesAsync = ref.watch(resourcesStreamProvider);
    final configAsync = ref.watch(farmConfigStreamProvider);

    return resourcesAsync.when(
      data: (resources) {
        return configAsync.when(
          data: (config) {
            final filteredResources = resources.where((resource) {
              final query = searchQuery.toLowerCase();
              final categoryName = _getCategoryConfig(
                config,
                resource.categoryId,
              ).name;
              return resource.title.toLowerCase().contains(query) ||
                  categoryName.toLowerCase().contains(query);
            }).toList();

            if (filteredResources.isEmpty) {
              return Center(
                child: Text(
                  searchQuery.isEmpty
                      ? 'No hi ha recursos afegits.'
                      : 'No s\'han trobat resultats.',
                ),
              );
            }

            // Grouping by Category ID
            final Map<String, List<Resource>> grouped = {};
            for (var r in filteredResources) {
              if (!grouped.containsKey(r.categoryId)) {
                grouped[r.categoryId] = [];
              }
              grouped[r.categoryId]!.add(r);
            }

            final sortedKeys = grouped.keys.toList()
              ..sort((a, b) {
                final nameA = _getCategoryConfig(config, a).name;
                final nameB = _getCategoryConfig(config, b).name;
                return nameA.compareTo(nameB);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedKeys.length + 1,
              itemBuilder: (context, index) {
                if (index == sortedKeys.length) {
                  return const SizedBox(height: 80); // Padding
                }

                final catId = sortedKeys[index];
                final categoryConfig = _getCategoryConfig(config, catId);
                final categoryResources = grouped[catId]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            IconData(
                              categoryConfig.iconCode,
                              fontFamily: 'MaterialIcons',
                            ),
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            categoryConfig.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          // Config button moved to AppBar
                        ],
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: categoryResources.map((resource) {
                          final typeConfig = _getTypeConfig(
                            config,
                            resource.typeId,
                          );
                          final typeColor = Color(
                            int.parse(typeConfig.colorHex, radix: 16),
                          );

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                IconData(
                                  typeConfig.iconCode,
                                  fontFamily: 'MaterialIcons',
                                ),
                                color: typeColor,
                              ),
                            ),
                            title: Text(
                              resource.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              resource.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _openResource(resource),
                                  child: const Text('OBRIR'),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) {
                                    if (val == 'edit') onEdit(resource);
                                    if (val == 'delete') {
                                      _deleteResource(context, ref, resource);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _openResource(resource),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(), // Wait for config
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
