import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'zone_editor_page.dart';
import 'espai_list_page.dart';
import 'hort_library_page.dart';
import 'rotation_patterns_page.dart';

class HorticulturePage extends ConsumerStatefulWidget {
  const HorticulturePage({super.key});

  @override
  ConsumerState<HorticulturePage> createState() => _HorticulturePageState();
}

class _HorticulturePageState extends ConsumerState<HorticulturePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestió d\'Horticultura'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_library),
            tooltip: 'Biblioteca d\'Hort',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HortLibraryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync), // Rotation icon
            tooltip: 'Patrons de Rotació',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RotationPatternsPage(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Zones (Mapa)'),
            Tab(icon: Icon(Icons.grid_on), text: 'Dissenyador'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [const ZoneEditorPage(), const EspaiListPage()],
      ),
    );
  }
}
