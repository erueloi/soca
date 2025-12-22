import 'package:flutter/material.dart';

import '../widgets/irrigation_widget.dart';
import '../widgets/soca_drawer.dart';
import '../widgets/task_bucket_widget.dart';
import '../widgets/tree_summary_widget.dart';
import '../widgets/weather_widget.dart';

import '../../../../features/tasks/presentation/pages/tasks_page.dart';
import '../../../../features/contacts/presentation/pages/contacts_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for Tablet (e.g. 800px)
        final bool isWideScreen = constraints.maxWidth > 800;

        return Scaffold(
          appBar: isWideScreen ? null : AppBar(title: const Text('Soca')),
          drawer: isWideScreen ? null : const SocaDrawer(),
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  selectedIndex: 0,
                  extended:
                      constraints.maxWidth > 1200, // Collapsible on tablet
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedIconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  leading: Column(
                    children: [
                      const SizedBox(height: 16),
                      Icon(
                        Icons.spa,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      if (constraints.maxWidth > 1200) ...[
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
                          'Molí de Cal Jeroni',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                  onDestinationSelected: (int index) {
                    if (index == 5) {
                      _navigateToTasks(context);
                    } else if (index == 6) {
                      _navigateToContacts(context);
                    } else if (index == 7) {
                      launchUrl(Uri.parse('/soca.apk'));
                    }
                  },
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
                      icon: Icon(Icons.water_drop_outlined),
                      selectedIcon: Icon(Icons.water_drop),
                      label: Text('Reg'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.forest_outlined),
                      selectedIcon: Icon(Icons.forest),
                      label: Text('Arbres'),
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
                      icon: Icon(Icons.android),
                      selectedIcon: Icon(Icons.android, color: Colors.green),
                      label: Text('Descarregar App'),
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
                          child: Text(
                            'Tauler de Control', // Dashboard title for desktop
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
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
                        delegate: SliverChildListDelegate(const [
                          WeatherWidget(),
                          TreeSummaryWidget(),
                          IrrigationWidget(),
                          TaskBucketWidget(),
                        ]),
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
