import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import 'core/providers/app_version_provider.dart';

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
      scrollBehavior: AppScrollBehavior(),
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

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEFEBE9),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/splash-logo.png',
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: versionAsync.when(
                  data: (version) => Text(
                    'v$version',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF556B2F),
                      letterSpacing: 0.5,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
