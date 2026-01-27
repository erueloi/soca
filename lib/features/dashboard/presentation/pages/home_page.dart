import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed

import '../../../../core/services/version_check_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soca/features/auth/data/repositories/auth_repository.dart';
import '../../../../core/services/notification_service.dart'; // Added
import '../../../../features/settings/presentation/providers/settings_provider.dart';
import '../../../../features/settings/domain/entities/farm_config.dart'; // Added
import '../../../../features/climate/presentation/pages/clima_page.dart';
import '../../../../features/tasks/presentation/pages/tasks_page.dart';
import '../../../contacts/presentation/pages/contacts_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../trees/presentation/pages/trees_page.dart';
import '../../../trees/presentation/pages/watering_page.dart';
import '../../../settings/presentation/pages/farm_profile_page.dart';
import '../../../construction/presentation/pages/construction_page.dart';
import '../../../horticulture/presentation/pages/horticulture_page.dart';
import '../../../auth/presentation/pages/user_profile_page.dart';

import '../widgets/irrigation_widget.dart';
import '../widgets/soca_drawer.dart';
import '../widgets/task_bucket_widget.dart';
import '../widgets/tree_summary_widget.dart';
import '../widgets/weather_widget.dart';
import '../widgets/dashboard_agenda_widget.dart';
import '../widgets/farm_status_widget.dart';

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
    // _loadOrder(); // Removing manual load, relying on stream listener
    _setupInteractedMessage();
    // Check for updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionCheckService().checkForUpdates(context);
    });

    // Initialize Notifications (Post-Login)
    // This will ask for permission if not granted
    notificationService.initialize().catchError((e) {
      debugPrint('Error initializing notifications: $e');
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
    'farm_status',
  ];

  final Map<String, String> _widgetNames = {
    'weather': 'Temps',
    'trees': 'Resum Arbres',
    'irrigation': 'Reg',
    'buckets': 'Tasques per Partida',
    'agenda': 'Agenda',
    'farm_status': 'Estat Masia',
  };

  Future<void> _loadOrder(FarmConfig config) async {
    // If config has order, use it
    if (config.dashboardOrder.isNotEmpty) {
      if (_widgetOrder != config.dashboardOrder) {
        // Only update if different to avoid constant rebuilds/loops if setState called wrongly
        // Check if we need to merge new widgets
        // final currentKeys = _widgetOrder.toSet(); // Unused
        final savedKeys = config.dashboardOrder.toSet();
        final newOrder = List<String>.from(config.dashboardOrder);

        // Add any default widgets that might be missing from saved config (new features)
        for (final key in _defaultWidgetOrder) {
          if (!savedKeys.contains(key)) {
            newOrder.add(key);
          }
        }

        // Update local state if needed
        if (mounted &&
            (newOrder.length != _widgetOrder.length ||
                newOrder.join(',') != _widgetOrder.join(','))) {
          setState(() {
            _widgetOrder = newOrder;
          });
        }
      }
    }
  }

  Future<void> _saveOrder() async {
    // Save to Firebase via SettingsRepository
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final currentConfig = ref.read(farmConfigStreamProvider).value;

    if (currentConfig != null) {
      final newConfig = currentConfig.copyWith(dashboardOrder: _widgetOrder);
      await settingsRepo.saveFarmConfig(newConfig);
    }
  }

  Future<void> _ensureFincaId(FarmConfig config) async {
    // 1. Auto-repair Config
    if (config.fincaId == null || config.fincaId!.isEmpty) {
      debugPrint("FincaId missing. Triggering auto-repair...");
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.saveFarmConfig(config);
      return; // Return, fetch will happen again via stream
    }

    // 2. Auto-repair User Authorization
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final firestoreHandler = FirebaseFirestore.instance;
      final userDocRef = firestoreHandler.collection('users').doc(user.uid);

      try {
        final userSnapshot = await userDocRef.get();
        if (userSnapshot.exists) {
          final data = userSnapshot.data() ?? {};
          final List<dynamic> authorized = data['authorizedFincas'] ?? [];

          if (!authorized.contains(config.fincaId)) {
            debugPrint(
              "User not authorized for this fincaId. Self-authorizing based on email access...",
            );
            // We can do this because they successfully read the config (email match),
            // and they can write their own user doc.
            await userDocRef.update({
              'authorizedFincas': FieldValue.arrayUnion([config.fincaId]),
            });
          }
        }
      } catch (e) {
        debugPrint("Error syncing user authorization: $e");
      }
    }
  }

  final List<String> _defaultWidgetOrder = [
    'weather',
    'trees',
    'irrigation',
    'buckets',
    'agenda',
    'farm_status',
  ];

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
      case 'farm_status':
        return const FarmStatusWidget();
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

    // Sync order when config loads
    farmConfigAsync.whenData((config) {
      // We can't call setState directly during build if value changes,
      // but _loadOrder has a guard.
      // Better approach: Use a separate useEffect or simple check.
      // Since this is a StatefulWidget, we can just check if we need to update.
      // However, to avoid build-cycle issues preferably we'd use listen, but watch is fine if we start with defaults.
      // Let's trigger a microtask or check in body?
      // Actually, easiest is to use ref.listen in build.
    });

    // Better: Ref listen
    ref.listen(farmConfigStreamProvider, (previous, next) {
      next.whenData((config) {
        _loadOrder(config);
        _ensureFincaId(config);
      });
    });

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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HorticulturePage(),
                        ),
                      );
                    } else if (index == 7) {
                      _navigateToTasks(context);
                    } else if (index == 8) {
                      _navigateToContacts(context);
                    } else if (index == 3) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const WateringPage(),
                        ),
                      );
                    } else if (index == 9) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FarmProfilePage(),
                        ),
                      );
                    } else if (index == 10) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UserProfilePage(),
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
                      icon: Icon(Icons.grass),
                      selectedIcon: Icon(Icons.grass_outlined),
                      label: Text('Hort'),
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
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Perfil'),
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
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent:
                                350.0, // Targets ~3 cols on landscape tablet (1024px)
                            mainAxisSpacing: 16.0,
                            crossAxisSpacing: 16.0,
                            childAspectRatio: isWideScreen
                                ? 1.1
                                : 0.85, // Taller cards on mobile
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
