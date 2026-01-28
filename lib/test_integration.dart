import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:soca/core/config/firebase_options.dart';
import 'package:soca/features/climate/data/repositories/climate_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/features/auth/data/repositories/auth_repository.dart';

// RUN WITH: flutter run -d windows -t lib/test_integration.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MaterialApp(home: TestPage())));
}

class TestPage extends ConsumerStatefulWidget {
  const TestPage({super.key});

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

class _TestPageState extends ConsumerState<TestPage> {
  String _status = 'Ready to test...';
  // Repositories are now accessed via ref.read/watch

  @override
  void initState() {
    super.initState();
    // Check auth status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      _log('Logged in as: ${user.email}');
    } else {
      _log('⚠️ Not logged in. Please Sign In first.');
    }
  }

  void _signIn() async {
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      _log('✅ Logged in successfully!');
      setState(() {});
    } catch (e) {
      _log('❌ Login failed: $e');
    }
  }

  void _runTest() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (authRepo.currentUser == null) {
      _log('❌ Please Log In before running the test.');
      return;
    }
    setState(() => _status = 'Running test...\n');

    try {
      final now = DateTime.now();
      // Using a temporary repo instance for specific finca testing
      // OR use the provider if it's set up for the current finca.
      // Let's create one manually to be safe like before, but inside the method.
      final climateRepo = ClimateRepository(fincaId: 'mol-cal-jeroni');

      // 1. Fetch Data
      _log('Fetching history for Jan 2026...');
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 28);
      final history = await climateRepo.getHistory(start, end);

      _log('Found ${history.length} records.');
      if (history.isNotEmpty) {
        _log('First record date: ${history.first.date}');
        _log('First record type: ${history.first.date.runtimeType}');
      }

      // 2. Recalculate
      _log('\nRunning recalculateSoilBalance...');
      await climateRepo.recalculateSoilBalance(now, 41.51); // Lat La Floresta
      _log('Recalculation complete.');

      // 3. Verify
      final lastCalc = await climateRepo.getLastCalculationTimestamp();
      _log('Last Calculation Timestamp: $lastCalc');

      if (lastCalc != null &&
          lastCalc.difference(DateTime.now()).inMinutes < 2) {
        _log('\n✅ SUCCESS: Calculation timestamp updated recently!');
      } else {
        _log('\n⚠️ WARNING: Calculation timestamp seems old or null.');
      }
    } catch (e, stack) {
      _log('\n❌ ERROR: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  void _log(String msg) {
    setState(() => _status += '$msg\n');
    debugPrint(msg);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Test Integration')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (user == null)
              ElevatedButton(
                onPressed: _signIn,
                child: const Text('LOGIN WITH GOOGLE'),
              ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _runTest, child: const Text('RUN TEST')),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.black12,
                child: SingleChildScrollView(
                  child: Text(
                    _status,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
