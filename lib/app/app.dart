import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/log.dart';
import '../data/dictionary_repository.dart';
import '../data/local_store.dart';
import '../data/search_engine.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../state/library_controller.dart';
import '../ui/screens/home_shell.dart';
import 'app_scope.dart';
import 'theme.dart';

/// Everything the UI needs, created once at startup.
class AppServices {
  AppServices({
    required this.dictionary,
    required this.search,
    required this.library,
    this.analytics = const NoopAnalytics(),
    this.ads = const NoopAds(),
  });

  final DictionaryRepository dictionary;
  final SearchEngine search;
  final LibraryController library;
  final Analytics analytics;
  final Ads ads;

  /// Loads the bundled dictionary and the user's saved data in parallel.
  /// If platform storage cannot be opened, falls back to in-memory storage
  /// so the dictionary remains usable.
  static Future<AppServices> bootstrap({Future<KeyValueStore> Function()? storeFactory}) async {
    final dictFuture = DictionaryRepository.load();
    final analyticsFuture = _initAnalytics();
    KeyValueStore store;
    try {
      store = await (storeFactory ?? SharedPrefsStore.create)();
    } catch (e) {
      logDebug('Persistent storage unavailable, using memory: $e');
      store = MemoryStore();
    }
    final dictionary = await dictFuture;
    final library = LibraryController(store, validIds: dictionary.entries.map((e) => e.id).toSet());
    await library.load();
    return AppServices(
      dictionary: dictionary,
      search: SearchEngine(dictionary.entries),
      library: library,
      analytics: await analyticsFuture,
      ads: AdMobAds(),
    );
  }

  /// Firebase is optional at runtime: if it fails (e.g. Play services
  /// missing), the app runs without analytics.
  static Future<Analytics> _initAnalytics() async {
    try {
      await Firebase.initializeApp();
      return FirebaseAppAnalytics(FirebaseAnalytics.instance);
    } catch (e) {
      logDebug('Firebase unavailable, analytics disabled: $e');
      return const NoopAnalytics();
    }
  }
}

class FlirtDictApp extends StatefulWidget {
  const FlirtDictApp({super.key, this.bootstrap = AppServices.bootstrap});

  final Future<AppServices> Function() bootstrap;

  @override
  State<FlirtDictApp> createState() => _FlirtDictAppState();
}

class _FlirtDictAppState extends State<FlirtDictApp> {
  AppServices? _services;
  bool _failed = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.bootstrap();
      if (!mounted) return;
      // Make sure queued writes land before the OS may kill the process.
      _lifecycle?.dispose();
      _lifecycle = AppLifecycleListener(onPause: s.library.flush, onDetach: s.library.flush);
      setState(() => _services = s);
      // Consent + ad SDK start after the first frame so they never delay
      // startup; the consent form (EEA/UK only) needs a visible activity.
      WidgetsBinding.instance.addPostFrameCallback((_) => s.ads.initialize());
    } catch (e, st) {
      logDebug('Startup failed: $e\n$st');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    _load();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;
    return MaterialApp(
      title: 'Flirt Dictionary',
      debugShowCheckedModeBanner: false,
      navigatorObservers: s?.analytics.navigatorObservers ?? const [],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // AppScope must sit ABOVE the Navigator so every pushed route
      // (word detail, category, letter, collection) can reach it.
      builder: (context, child) => s == null
          ? child!
          : AppScope(dictionary: s.dictionary, search: s.search, library: s.library, child: child!),
      home: s != null
          ? const HomeShell()
          : _failed
          ? _StartupError(onRetry: _retry)
          : const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading dictionary')),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: Spacing.md),
                Text(
                  'The dictionary could not be loaded.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.md),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
