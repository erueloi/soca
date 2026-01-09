import 'package:flutter/material.dart';
import '../../../../features/climate/presentation/pages/clima_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../contacts/presentation/pages/contacts_page.dart';
import '../../../construction/presentation/pages/construction_page.dart';
import '../../../map/presentation/pages/map_page.dart';
import '../../../trees/presentation/pages/trees_page.dart';
import '../../../trees/presentation/pages/watering_page.dart';
import '../../../settings/presentation/pages/farm_profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SocaDrawer extends StatelessWidget {
  const SocaDrawer({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        // Changet ListView to Column to use Spacer
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.spa, size: 48, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        'Soca',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Molí de Cal Jeroni',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Mapa'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const MapPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Clima'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ClimaPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('Reg'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WateringPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.forest_outlined),
                  title: const Text("Arbres"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TreesPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.architecture_outlined),
                  title: const Text('Obres'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ConstructionPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Tasques'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TasksPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('Contactes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ContactsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configuració Finca'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FarmProfilePage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.android),
                  title: const Text('Descarregar App'),
                  onTap: () async {
                    Navigator.pop(context);
                    final Uri url = Uri.parse('/soca.apk');
                    if (!await launchUrl(url)) {
                      // Ignore error
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('Versió ${snapshot.data!.version}'),
                subtitle: const Text('Veure Novetats'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Novetats v${snapshot.data!.version}'),
                      content: FutureBuilder<String>(
                        future: DefaultAssetBundle.of(
                          context,
                        ).loadString('assets/release_notes.md'),
                        builder: (context, noteSnapshot) {
                          if (noteSnapshot.hasData) {
                            return SingleChildScrollView(
                              child: Text(noteSnapshot.data!),
                            );
                          }
                          return const CircularProgressIndicator();
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tancar'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
