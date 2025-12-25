import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/trees_provider.dart';
import '../../domain/entities/tree.dart';

class TreeDetail extends ConsumerWidget {
  final Tree tree;

  const TreeDetail({super.key, required this.tree});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ref),
          const SizedBox(height: 24),
          _buildAIDashboard(context),
          const SizedBox(height: 24),
          _buildTechnicalData(context),
          const SizedBox(height: 24),
          _buildFieldOperations(context, ref),
          const SizedBox(height: 24),
          _buildTimeline(context),
          const SizedBox(height: 24),
          _buildGISMap(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                image: (tree.photoUrl != null && tree.photoUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(tree.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[300],
              ),
              child: (tree.photoUrl == null || tree.photoUrl!.isEmpty)
                  ? const Center(
                      child: Icon(Icons.park, size: 80, color: Colors.green),
                    )
                  : null,
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _addTimelineEvent(
                  context,
                  ref,
                ), // We need ref here, pass it down?
                // Since buildHeader is separate, we need to pass ref.
                // Or better: make buildHeader take ref.
                label: const Text('Evolució'),
                icon: const Icon(Icons.add_a_photo),
                backgroundColor: Colors.white,
                foregroundColor: Colors.brown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          tree.commonName,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.brown[900],
          ),
        ),
        Text(
          tree.species,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey[700],
          ),
        ),
        if (tree.padrino != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: Colors.brown.shade100,
                child: Text(tree.padrino![0].toUpperCase()),
              ),
              label: Text('Padrí: ${tree.padrino}'),
              backgroundColor: Colors.brown.shade50,
            ),
          ),
      ],
    );
  }

  Widget _buildAIDashboard(BuildContext context) {
    final statusColor = _getStatusColor(tree.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Anàlisi IA (Gemini)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.purple.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.purple),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Salut',
                  tree.status,
                  icon: Icons.health_and_safety,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Vigor',
                  tree.vigor ?? 'N/A',
                  icon: Icons.speed,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (tree.maintenanceTips != null || tree.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consells / Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(tree.maintenanceTips ?? tree.notes),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechnicalData(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fitxa Tècnica',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildTechItem('Funció', tree.ecologicalFunction ?? '-', Icons.eco),
            _buildTechItem(
              'Format',
              tree.plantingFormat ?? '-',
              Icons.inventory_2,
            ),
            _buildTechItem('Proveïdor', tree.provider ?? '-', Icons.store),
            _buildTechItem(
              'Preu',
              tree.price != null ? '${tree.price}€' : '-',
              Icons.euro,
            ),
            _buildTechItem(
              'Data',
              '${tree.plantingDate.day}/${tree.plantingDate.month}/${tree.plantingDate.year}',
              Icons.calendar_today,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTechItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldOperations(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vincular Tasca: Pendent d\'implementar'),
                ),
              );
            },
            icon: const Icon(Icons.add_task),
            label: const Text('TASCA MANTENIMENT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _assignPadrino(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('ASSIGNAR PADRÍ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) {
    if (tree.timeline.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evolució',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tree.timeline.length,
            itemBuilder: (context, index) {
              final event = tree.timeline[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: event.photoUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                event.photoUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : const Icon(Icons.photo, color: Colors.grey),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '${event.date.day}/${event.date.month}/${event.date.year}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGISMap(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Localització GIS',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(tree.latitude, tree.longitude),
                initialZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.soca',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(tree.latitude, tree.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.map),
            label: const Text('Obrir a Google Maps'),
            onPressed: () async {
              final url = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${tree.latitude},${tree.longitude}',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'viable':
        return Colors.green;
      case 'mort':
        return Colors.red;
      case 'malalt':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _addTimelineEvent(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final tryPicked = await picker.pickImage(source: ImageSource.camera);
    if (tryPicked == null) return;
    final picked = tryPicked; // Cast XFile? to XFile for use

    String? note;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nota d\'evolució'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Descriu el canvi...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () {
                note = controller.text;
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (note == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pujant foto...')));

    final repo = ref.read(treesRepositoryProvider);
    final url = await repo.uploadTreeImage(picked, tree.id);

    if (url != null) {
      final event = TreeEvent(date: DateTime.now(), photoUrl: url, note: note!);
      await repo.addTimelineEvent(tree.id, event);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Esdeveniment afegit!')));
      }
    }
  }

  Future<void> _assignPadrino(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: tree.padrino ?? '');
    String? newPadrino;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assignar Padrí'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nom del responsable'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () {
                newPadrino = controller.text;
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (newPadrino == null) return;

    final repo = ref.read(treesRepositoryProvider);
    final updatedTree = tree.copyWith(padrino: newPadrino);
    await repo.updateTree(updatedTree);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Padrí assignat: $newPadrino')));
    }
  }
}
