import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app_scope.dart';

import 'screens/category_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/letter_screen.dart';
import 'screens/word_detail_screen.dart';

/// True while a page transition started by [_push] is running. Further
/// pushes are ignored until it finishes, so rapid repeated taps can never
/// stack duplicate pages.
bool _pushing = false;

Future<void> _push(BuildContext context, Widget page, String name) {
  if (_pushing) return Future.value();
  _pushing = true;
  final route = MaterialPageRoute<void>(
    builder: (_) => page,
    settings: RouteSettings(name: name),
  );
  final result = Navigator.of(context).push(route);
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final animation = route.animation;
    if (animation == null || animation.status != AnimationStatus.forward) {
      _pushing = false;
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.forward) return;
      animation.removeStatusListener(listener);
      _pushing = false;
    }

    animation.addStatusListener(listener);
  });
  return result;
}

@visibleForTesting
void resetNavigationCooldown() => _pushing = false;

/// Opens a word's detail page. [source] records where the user came from
/// (search, browse, related, …) for analytics.
Future<void> openWord(BuildContext context, String wordId, {String source = 'list'}) {
  if (_pushing) return Future.value();
  final scope = AppScope.of(context);
  scope.analytics.viewWord(wordId, source: source);
  scope.ads.onWordOpened();
  return _push(context, WordDetailScreen(wordId: wordId), '/word/$wordId');
}

Future<void> openCategory(BuildContext context, String categoryId) =>
    _push(context, CategoryScreen(categoryId: categoryId), '/category/$categoryId');

Future<void> openLetter(BuildContext context, String letter) =>
    _push(context, LetterScreen(initialLetter: letter), '/letter/$letter');

Future<void> openCollection(BuildContext context, String collectionId) =>
    _push(context, CollectionScreen(collectionId: collectionId), '/collection/$collectionId');
