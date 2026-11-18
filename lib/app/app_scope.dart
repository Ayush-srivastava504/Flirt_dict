import 'package:flutter/widgets.dart';

import '../data/dictionary_repository.dart';
import '../data/search_engine.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../state/library_controller.dart';

/// Provides app-wide services to the widget tree. The services themselves
/// never change after startup, so dependents only rebuild on library changes
/// when they explicitly listen to [library].
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dictionary,
    required this.search,
    required this.library,
    this.analytics = const NoopAnalytics(),
    this.ads = const NoopAds(),
    required super.child,
  });

  final DictionaryRepository dictionary;
  final SearchEngine search;
  final LibraryController library;
  final Analytics analytics;
  final Ads ads;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dictionary != oldWidget.dictionary ||
      search != oldWidget.search ||
      library != oldWidget.library ||
      analytics != oldWidget.analytics ||
      ads != oldWidget.ads;
}
