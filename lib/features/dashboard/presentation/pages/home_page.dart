import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/version_check_service.dart';
import '../../../../features/settings/presentation/providers/settings_provider.dart';
import '../../../../features/climate/presentation/pages/clima_page.dart';
import '../../../../features/tasks/presentation/pages/tasks_page.dart';
import '../../../contacts/presentation/pages/contacts_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../trees/presentation/pages/trees_page.dart';
import '../../../trees/presentation/pages/watering_page.dart';
import '../../../settings/presentation/pages/farm_profile_page.dart';
import '../../../construction/presentation/pages/construction_page.dart';

import '../widgets/irrigation_widget.dart';
import '../widgets/soca_drawer.dart';
import '../widgets/task_bucket_widget.dart';
import '../widgets/tree_summary_widget.dart';
import '../widgets/weather_widget.dart';
import '../widgets/dashboard_agenda_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // ... existing code ...
  bool? _isRailExtended;

  void _navigateToTasks(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const TasksPage()));
  }

  void _navigateToContacts(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ContactsPage()));
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _setupInteractedMessage();
    // Check for updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionCheckService().checkForUpdates(context);
    });
  }

  // Handle Notification Clicks
  Future<void> _setupInteractedMessage() async {
    // 1. App Terminated
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. App in Background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['route'] == '/tasks') {
      final dateStr = message.data['date'];
      DateTime? initialDate;
      if (dateStr != null) {
        initialDate = DateTime.tryParse(dateStr);
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TasksPage(initialDate: initialDate),
        ),
      );
    }
  }

  bool _isEditing = false;
  List<String> _widgetOrder = [
    'weather',
    'trees',
    'irrigation',
    'buckets',
    'agenda',
  ];

  final Map<String, String> _widgetNames = {
    'weather': 'Temps',
    'trees': 'Resum Arbres',
    'irrigation': 'Reg',
    'buckets': 'Tasques per Partida',
    'agenda': 'Agenda',
  };

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('dashboard_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      // Ensure all current widgets are present (handle new widgets added in updates)
      final currentKeys = _widgetOrder.toSet();
      final savedKeys = savedOrder.toSet();

      // Add saved keys that are still valid
      final newOrder = savedOrder
          .where((key) => currentKeys.contains(key))
          .toList();

      // Append any new widgets that weren't in the saved list
      for (final key in _widgetOrder) {
        if (!savedKeys.contains(key)) {
          newOrder.add(key);
        }
      }

      setState(() {
        _widgetOrder = newOrder;
      });
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dashboard_order', _widgetOrder);
  }

  Widget _getWidgetByKey(String key) {
    switch (key) {
      case 'weather':
        return const WeatherWidget();
      case 'trees':
        return const TreeSummaryWidget();
      case 'irrigation':
        return const IrrigationWidget();
      case 'buckets':
        return const TaskBucketWidget();
      case 'agenda':
        return const DashboardAgendaWidget();
      default:
        return const SizedBox.shrink();
    }
  }

  void _navigateToTrees(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const TreesPage()));
  }

  @override
  Widget build(BuildContext context) {
    final farmConfigAsync = ref.watch(farmConfigStreamProvider);
    final farmName = farmConfigAsync.when(
      data: (config) => config.name,
      loading: () => 'Carregant...',
      error: (err, stack) => 'Soca',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for Tablet (e.g. 800px)
        final bool isWideScreen = constraints.maxWidth > 800;

        // Auto-extended if very wide (> 1200), unless manually toggled
        final bool autoExtended = constraints.maxWidth > 1200;
        final bool isRailExtended = _isRailExtended ?? autoExtended;

        return Scaffold(
          appBar: isWideScreen ? null : AppBar(title: const Text('Soca')),
          drawer: isWideScreen ? null : const SocaDrawer(),
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  selectedIndex: 0,
                  extended: isRailExtended,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedIconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  leading: GestureDetector(
                    onTap: () {
                      setState(() {
                        // Toggle state. If it was null (auto), we flip auto.
                        _isRailExtended = !isRailExtended;
                      });
                    },
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Image.asset(
                          'assets/logo-soca.png',
                          height: isRailExtended ? 80 : 48,
                        ),
                        if (isRailExtended) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Soca',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            farmName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  onDestinationSelected: (int index) {
                    if (index == 1) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MapPage(),
                        ),
                      );
                    } else if (index == 2) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ClimaPage(),
                        ),
                      );
                    } else if (index == 4) {
                      // Arbres index
                      _navigateToTrees(context);
                    } else if (index == 5) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ConstructionPage(),
                        ),
                      );
                    } else if (index == 6) {
                      _navigateToTasks(context);
                    } else if (index == 7) {
                      _navigateToContacts(context);
                    } else if (index == 3) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const WateringPage(),
                        ),
                      );
                    } else if (index == 8) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FarmProfilePage(),
                        ),
                      );
                    }
                  },
                  trailing: Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Divider(),
                          // Download App
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('https://soca-aacac.web.app/soca.apk'),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(
                              Icons.android,
                              color: Colors.green,
                            ),
                            label: isRailExtended
                                ? const Text('App')
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 8),
                          // Release Notes / Version
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'Versió ${snapshot.data!.version}',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        'Novetats v${snapshot.data!.version}',
                                      ),
                                      content: SizedBox(
                                        width: 400,
                                        child: FutureBuilder<String>(
                                          future: DefaultAssetBundle.of(context)
                                              .loadString(
                                                'assets/release_notes.md',
                                              ),
                                          builder: (context, noteSnapshot) {
                                            if (noteSnapshot.hasData) {
                                              return SingleChildScrollView(
                                                child: Text(noteSnapshot.data!),
                                              );
                                            }
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Tancar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: Text('Mapa'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.cloud_outlined),
                      selectedIcon: Icon(Icons.cloud),
                      label: Text('Clima'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.water_drop_outlined),
                      selectedIcon: Icon(Icons.water_drop),
                      label: Text('Reg'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.forest_outlined),
                      selectedIcon: Icon(Icons.forest),
                      label: Text('Arbres'), // Index is 3
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.architecture_outlined),
                      selectedIcon: Icon(Icons.architecture),
                      label: Text('Obres'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.check_circle_outline),
                      selectedIcon: Icon(Icons.check_circle),
                      label: Text('Tasques'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt),
                      label: Text('Contactes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Configuració'),
                    ),
                  ],
                ),
              if (isWideScreen) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (isWideScreen)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tauler de Control', // Dashboard title for desktop
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              IconButton(
                                icon: Icon(
                                  _isEditing ? Icons.check : Icons.edit,
                                ),
                                onPressed: () {
                                  if (_isEditing) {
                                    _saveOrder();
                                  }
                                  setState(() {
                                    _isEditing = !_isEditing;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isEditing)
                      SliverReorderableList(
                        itemBuilder: (context, index) {
                          final key = _widgetOrder[index];
                          return ReorderableDragStartListener(
                            key: ValueKey(key),
                            index: index,
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                leading: const Icon(Icons.drag_handle),
                                title: Text(_widgetNames[key] ?? key),
                              ),
                            ),
                          );
                        },
                        itemCount: _widgetOrder.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = _widgetOrder.removeAt(oldIndex);
                            _widgetOrder.insert(newIndex, item);
                          });
                        },
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    350.0, // Targets ~3 cols on landscape tablet (1024px)
                                mainAxisSpacing: 16.0,
                                crossAxisSpacing: 16.0,
                                childAspectRatio: 1.1,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _getWidgetByKey(_widgetOrder[index]);
                          }, childCount: _widgetOrder.length),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
