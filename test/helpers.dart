import 'dart:io';

import 'package:flirt_dict/app/app.dart';
import 'package:flirt_dict/data/dictionary_repository.dart';
import 'package:flirt_dict/data/local_store.dart';
import 'package:flirt_dict/data/search_engine.dart';
import 'package:flirt_dict/state/library_controller.dart';
import 'package:flirt_dict/ui/screens/category_screen.dart';
import 'package:flirt_dict/ui/screens/letter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real bundled dictionary, read straight from disk.
DictionaryRepository loadRealDictionary() =>
    DictionaryRepository.fromJsonString(File(DictionaryRepository.assetPath).readAsStringSync());

final DictionaryRepository realDictionary = loadRealDictionary();

Future<AppServices> buildServices([KeyValueStore? store]) async {
  final library = LibraryController(
    store ?? MemoryStore(),
    validIds: realDictionary.entries.map((e) => e.id).toSet(),
  );
  await library.load();
  return AppServices(
    dictionary: realDictionary,
    search: SearchEngine(realDictionary.entries),
    library: library,
  );
}

/// Pumps the full app with in-memory storage and returns its services.
Future<AppServices> pumpApp(
  WidgetTester tester, {
  KeyValueStore? store,
  Size size = const Size(412, 915),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final services = await buildServices(store);
  await tester.pumpWidget(FlirtDictApp(bootstrap: () async => services));
  await tester.pumpAndSettle();
  return services;
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Scrolls the word list on the current Letter screen until [word] is
/// built and visible (lists are lazy, so off-screen rows don't exist yet).
Future<void> scrollToWordInLetter(WidgetTester tester, String word) => tester.scrollUntilVisible(
  find.text(word),
  300,
  scrollable: _verticalScrollableIn(find.byType(LetterScreen)),
);

/// Same as [scrollToWordInLetter] for a Category screen.
Future<void> scrollToWordInCategory(WidgetTester tester, String word) => tester.scrollUntilVisible(
  find.text(word),
  300,
  scrollable: _verticalScrollableIn(find.byType(CategoryScreen)),
);

/// The vertical list inside [screen] (screens may also contain horizontal
/// chip strips, which must not be scrolled when looking for a word).
Finder _verticalScrollableIn(Finder screen) => find.descendant(
  of: screen,
  matching: find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
);
