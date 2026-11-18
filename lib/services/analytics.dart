import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

import '../core/log.dart';

/// App-level analytics events. Only anonymous usage data is recorded:
/// dictionary word IDs, search terms typed into the dictionary, and which
/// features are used. No names, emails or other personal data.
abstract class Analytics {
  /// Observers that report screen views for named routes.
  List<NavigatorObserver> get navigatorObservers;

  void screen(String name);
  void viewWord(String wordId, {required String source});
  void search(String term, {String? categoryId, required int results});
  void favourite(String wordId, {required bool added});
  void share(String wordId);
  void copy(String wordId);
  void collectionCreated();
  void wordOfTheDayOpened(String wordId);
}

/// Used in tests and if Firebase fails to initialise.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();
  @override
  List<NavigatorObserver> get navigatorObservers => const [];
  @override
  void screen(String name) {}
  @override
  void viewWord(String wordId, {required String source}) {}
  @override
  void search(String term, {String? categoryId, required int results}) {}
  @override
  void favourite(String wordId, {required bool added}) {}
  @override
  void share(String wordId) {}
  @override
  void copy(String wordId) {}
  @override
  void collectionCreated() {}
  @override
  void wordOfTheDayOpened(String wordId) {}
}

/// Firebase Analytics implementation. Every call is fire-and-forget and
/// swallows errors: analytics must never break the app.
class FirebaseAppAnalytics implements Analytics {
  FirebaseAppAnalytics(this._fa);

  final FirebaseAnalytics _fa;

  @override
  late final List<NavigatorObserver> navigatorObservers = [
    FirebaseAnalyticsObserver(analytics: _fa, nameExtractor: _routeName),
  ];

  /// Collapses `/word/ghosting` to `/word` so screen reports group by screen
  /// type; the specific word is reported separately via [viewWord].
  static String? _routeName(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;
    final parts = name.split('/');
    return parts.length > 1 && parts[1].isNotEmpty ? '/${parts[1]}' : name;
  }

  void _send(Future<void> Function() call) {
    call().catchError((Object e) => logDebug('Analytics error: $e'));
  }

  @override
  void screen(String name) => _send(() => _fa.logScreenView(screenName: name));

  @override
  void viewWord(String wordId, {required String source}) => _send(
    () => _fa.logEvent(name: 'view_word', parameters: {'word_id': wordId, 'source': source}),
  );

  @override
  void search(String term, {String? categoryId, required int results}) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) return;
    _send(
      () => _fa.logSearch(
        searchTerm: t.length > 100 ? t.substring(0, 100) : t,
        parameters: {'category': categoryId ?? 'all', 'results': results},
      ),
    );
  }

  @override
  void favourite(String wordId, {required bool added}) => _send(
    () => _fa.logEvent(
      name: added ? 'favourite_add' : 'favourite_remove',
      parameters: {'word_id': wordId},
    ),
  );

  @override
  void share(String wordId) =>
      _send(() => _fa.logShare(contentType: 'word', itemId: wordId, method: 'system_sheet'));

  @override
  void copy(String wordId) =>
      _send(() => _fa.logEvent(name: 'copy_word', parameters: {'word_id': wordId}));

  @override
  void collectionCreated() => _send(() => _fa.logEvent(name: 'collection_create'));

  @override
  void wordOfTheDayOpened(String wordId) =>
      _send(() => _fa.logEvent(name: 'word_of_the_day_open', parameters: {'word_id': wordId}));
}
