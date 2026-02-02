import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/firebase_options.dart';
import 'core/theme/app_theme.dart';

import 'features/dashboard/presentation/pages/home_page.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/settings/presentation/pages/app_config_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/widgets/widget_sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ca_ES', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: SocaApp()));

  // Register Background Callback (only on mobile platforms)
  if (!kIsWeb) {
    await HomeWidget.registerInteractivityCallback(
      homeWidgetBackgroundCallback,
    );
  }
}

class SocaApp extends ConsumerWidget {
  const SocaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmConfigAsync = ref.watch(farmConfigStreamProvider);
    final authStateAsync = ref.watch(authStateProvider);

    final farmTitle = farmConfigAsync.when(
      data: (config) => 'Soca - ${config.name}',
      loading: () => 'Soca',
      error: (err, stack) => 'Soca',
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: farmTitle,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ca', 'ES'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      routes: {'/config': (context) => const AppConfigPage()},
      home: WidgetSyncManager(
        child: authStateAsync.when(
          data: (user) {
            if (user == null) {
              return const LoginPage();
            }
            // Optionally check if email is verified or authorization is strictly needed here?
            // For now, Firestore rules handle authorization, so even if logged in but unauthorized,
            // they'll see empty data. We could add an "UnauthorizedPage" later if needed.
            return const HomePage();
          },
          loading: () =>
              const WelcomeScreen(), // Use WelcomeScreen while checking auth
          error: (e, s) =>
              Scaffold(body: Center(child: Text('Error d\'autenticació: $e'))),
        ),
      ),
    );
  }
}

// Background Callback (Entry Point)
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  // Logic to handle background updates if triggered by widget
  // Initialize Firebase and update widgets if necessary
  // For now, allow default behavior or implement simple fetch
  // Note: full dependency injection is hard here without setup.
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, size: 80, color: Colors.brown),
            const SizedBox(height: 16),
            Text(
              'Soca',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.brown,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Molí de Cal Jeroni',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.brown[700]),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
