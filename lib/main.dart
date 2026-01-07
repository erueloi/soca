import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/pages/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ca_ES', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Authenticate anonymously if not logged in
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
    }
  }

  // Enable offline persistence
  // Note regarding Blaze Plan (Pay-as-you-go):
  // Offline persistence helps reduce read operations by serving data from cache.
  // Future optimization: implementing specific cache strategies can further minimize costs.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: SocaApp()));
}

class SocaApp extends StatelessWidget {
  const SocaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Soca - Molí de Cal Jeroni',
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
      home: const HomePage(),
    );
  }
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
