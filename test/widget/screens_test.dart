import 'package:flirt_dict/data/local_store.dart';
import 'package:flirt_dict/ui/navigation.dart';
import 'package:flirt_dict/ui/screens/word_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The main scrollable of the word detail page (offstage tabs also contain
/// scrollables, so an unqualified search is ambiguous).
Finder detailScrollable() =>
    find.descendant(of: find.byType(WordDetailScreen), matching: find.byType(Scrollable)).first;

void main() {
  setUp(resetNavigationCooldown);

  group('Today', () {
    testWidgets('shows word of the day, categories and search shortcut', (tester) async {
      final s = await pumpApp(tester);
      final wotd = s.dictionary.wordOfTheDay(DateTime.now());
      expect(find.text('Flirt Dictionary'), findsOneWidget);
      expect(find.byKey(const ValueKey('word-of-the-day')), findsOneWidget);
      expect(find.text(wotd.word), findsWidgets);
      expect(find.text('Search ${s.dictionary.length} words…'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-slang')), findsOneWidget);
      // No recently viewed section on first launch.
      expect(find.text('Recently viewed'), findsNothing);
    });

    testWidgets('word of the day card opens detail, then appears in recent', (tester) async {
      final s = await pumpApp(tester);
      final wotd = s.dictionary.wordOfTheDay(DateTime.now());
      await tester.tap(find.byKey(const ValueKey('word-of-the-day')));
      await tester.pumpAndSettle();
      expect(find.byType(WordDetailScreen), findsOneWidget);
      expect(s.library.history.first, wotd.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Recently viewed'), 200);
      expect(find.text('Recently viewed'), findsOneWidget);
    });

    testWidgets('search shortcut switches to Search tab', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('Search ${realDictionary.length} words'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-field')), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const ValueKey('search-field')));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('category card opens category list', (tester) async {
      final s = await pumpApp(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('category-flags')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-flags')));
      await tester.pumpAndSettle();
      expect(find.text('Red & Green Flags'), findsOneWidget);
      expect(
        find.textContaining('${s.dictionary.inCategory('flags').length} words'),
        findsOneWidget,
      );
      expect(find.text('Beige Flag'), findsOneWidget);
    });
  });

  group('Browse', () {
    testWidgets('A–Z grid covers every letter and opens letter pages', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Browse');
      expect(find.byKey(const ValueKey('letter-A')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'no words')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('letter-X')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('letter-X')));
      await tester.pumpAndSettle();
      expect(find.text('Letter X'), findsOneWidget);
      expect(find.text('XOXO'), findsOneWidget);
    });

    testWidgets('letter screen lists words and switches letters', (tester) async {
      final s = await pumpApp(tester);
      await tapTab(tester, 'Browse');
      await tester.tap(find.byKey(const ValueKey('letter-G')));
      await tester.pumpAndSettle();
      expect(find.text('Letter G'), findsOneWidget);
      await scrollToWordInLetter(tester, 'Ghosting');
      expect(find.text('Ghosting'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chip-H')));
      await tester.pumpAndSettle();
      expect(find.text('Letter H'), findsOneWidget);
      expect(find.text(s.dictionary.forLetter('H').first.word), findsOneWidget);
    });

    testWidgets('category list opens categories', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Browse');
      await tester.scrollUntilVisible(find.text('Classic Romance'), 300);
      await tester.tap(find.text('Classic Romance'));
      await tester.pumpAndSettle();
      await scrollToWordInCategory(tester, 'Casanova');
      expect(find.text('Casanova'), findsOneWidget);
    });
  });

  group('Word detail', () {
    Future<void> openGhosting(WidgetTester tester) async {
      await tapTab(tester, 'Browse');
      await tester.tap(find.byKey(const ValueKey('letter-G')));
      await tester.pumpAndSettle();
      await scrollToWordInLetter(tester, 'Ghosting');
      await tester.tap(find.text('Ghosting'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all sections', (tester) async {
      await pumpApp(tester);
      await openGhosting(tester);
      expect(find.text('Ghosting'), findsOneWidget);
      expect(find.text('noun'), findsOneWidget);
      expect(find.text('Dating Slang'), findsOneWidget);
      expect(find.text('Examples'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Related words'),
        200,
        scrollable: detailScrollable(),
      );
      expect(find.text('Orbiting'), findsOneWidget);
    });

    testWidgets('favourite toggles and syncs to Saved tab', (tester) async {
      final s = await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.byTooltip('Add Ghosting to favourites'));
      await tester.pumpAndSettle();
      expect(s.library.isFavourite('ghosting'), isTrue);
      expect(find.byTooltip('Remove Ghosting from favourites'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapTab(tester, 'Saved');
      expect(find.text('Ghosting'), findsOneWidget);
    });

    testWidgets('copy puts formatted text on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, startsWith('Ghosting (noun)'));
      expect(find.text('Copied “Ghosting” to clipboard'), findsOneWidget);
    });

    testWidgets('share calls the platform share sheet once even on double tap', (tester) async {
      var calls = 0;
      Map? args;
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        args = call.arguments as Map;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
      );
      await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.text('Share'));
      await tester.pump();
      await tester.tap(find.text('Share'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(args!['text'], contains('Ghosting'));
      expect(args!['subject'], 'Ghosting');
    });

    testWidgets('share failure shows a friendly message', (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'error'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
      );
      await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(find.text('Sharing isn\'t available right now'), findsOneWidget);
    });

    testWidgets('related chip navigates to related word', (tester) async {
      await pumpApp(tester);
      await openGhosting(tester);
      await tester.scrollUntilVisible(
        find.widgetWithText(ActionChip, 'Orbiting'),
        200,
        scrollable: detailScrollable(),
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Orbiting'));
      await tester.pumpAndSettle();
      expect(find.text('Orbiting'), findsWidgets);
      expect(find.textContaining('social media posts'), findsOneWidget);
    });

    testWidgets('category chip opens category', (tester) async {
      await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.widgetWithText(ActionChip, 'Dating Slang'));
      await tester.pumpAndSettle();
      expect(find.text('Breadcrumbing'), findsOneWidget);
    });

    testWidgets('save to new collection via sheet', (tester) async {
      final s = await pumpApp(tester);
      await openGhosting(tester);
      await tester.tap(find.text('Save to…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      // Empty name is rejected.
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a name'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Modern dating');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(s.library.collections.single.name, 'Modern dating');
      expect(s.library.collections.single.wordIds, ['ghosting']);
      // Sheet now shows the collection checked; untick it.
      final tile = find.widgetWithText(CheckboxListTile, 'Modern dating');
      expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(s.library.collections.single.wordIds, isEmpty);
    });

    testWidgets('unknown word id shows not-found state', (tester) async {
      await pumpApp(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const WordDetailScreen(wordId: 'does-not-exist')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Word not found'), findsOneWidget);
    });

    testWidgets('rapid double tap opens only one detail page', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Browse');
      await tester.tap(find.byKey(const ValueKey('letter-G')));
      await tester.pumpAndSettle();
      await scrollToWordInLetter(tester, 'Ghosting');
      await tester.tap(find.text('Ghosting'));
      await tester.tap(find.text('Ghosting'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(WordDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Letter G'), findsOneWidget);
    });
  });

  group('Search', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('search-field')), text);
      await tester.pump(const Duration(milliseconds: 200)); // debounce
      await tester.pumpAndSettle();
    }

    testWidgets('empty state then results with count', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Search');
      expect(find.textContaining('Search ${realDictionary.length} words'), findsWidgets);
      await type(tester, 'ghost');
      expect(find.textContaining('result'), findsOneWidget);
      expect(find.byKey(const ValueKey('word-ghosting')), findsOneWidget);
    });

    testWidgets('no results shows did-you-mean that fixes the query', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Search');
      await type(tester, 'ghostng');
      expect(find.text('No matches for “ghostng”'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Ghosting'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-ghosting')), findsOneWidget);
    });

    testWidgets('category filter narrows results and can be reset', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Search');
      await type(tester, 'ghosting');
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('filter-classic')),
        find.byKey(const ValueKey('filter-bar')),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-classic')));
      await tester.pumpAndSettle();
      expect(find.text('Search all categories'), findsOneWidget);
      await tester.tap(find.text('Search all categories'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-ghosting')), findsOneWidget);
    });

    testWidgets('clear button empties the field', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Search');
      await type(tester, 'love');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const ValueKey('search-field')));
      expect(field.controller!.text, isEmpty);
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('opening a result saves a recent search that can be reused and removed', (
      tester,
    ) async {
      final s = await pumpApp(tester);
      await tapTab(tester, 'Search');
      await type(tester, 'crush');
      await tester.tap(find.byKey(const ValueKey('word-crush')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(s.library.recentSearches, ['crush']);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recent-crush')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recent-crush')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-crush')), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove “crush” from recent searches'));
      await tester.pumpAndSettle();
      expect(s.library.recentSearches, isEmpty);
    });

    testWidgets('submitting via keyboard records the search', (tester) async {
      final s = await pumpApp(tester);
      await tapTab(tester, 'Search');
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'flag');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(s.library.recentSearches, ['flag']);
    });

    testWidgets('typing keeps state when switching tabs', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Search');
      await type(tester, 'rizz');
      await tapTab(tester, 'Today');
      await tapTab(tester, 'Search');
      expect(find.byKey(const ValueKey('word-rizz')), findsOneWidget);
    });
  });

  group('Saved', () {
    testWidgets('empty states for all tabs', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Saved');
      expect(find.text('No favourites yet'), findsOneWidget);
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      expect(find.text('No collections yet'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
    });

    testWidgets('swipe to remove favourite with undo', (tester) async {
      final s = await pumpApp(tester);
      s.library.toggleFavourite('rizz');
      await tapTab(tester, 'Saved');
      await tester.drag(find.text('Rizz'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(s.library.isFavourite('rizz'), isFalse);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(s.library.isFavourite('rizz'), isTrue);
    });

    testWidgets('create, rename, remove word and delete collection', (tester) async {
      final s = await pumpApp(tester);
      await tapTab(tester, 'Saved');
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sweet');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final id = s.library.collections.single.id;
      s.library.toggleInCollection(id, 'darling');
      await tester.pumpAndSettle();
      expect(find.text('1 word'), findsOneWidget);

      await tester.tap(find.text('Sweet'));
      await tester.pumpAndSettle();
      expect(find.text('Darling'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Darling from Sweet'));
      await tester.pumpAndSettle();
      expect(find.text('This collection is empty'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Darling'), findsOneWidget);

      await tester.tap(find.byTooltip('Collection options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sweeter');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Sweeter'), findsOneWidget);

      await tester.tap(find.byTooltip('Collection options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(s.library.collections, isEmpty);
      expect(find.text('No collections yet'), findsOneWidget);
      expect(find.text('Collection not found'), findsNothing);
    });

    testWidgets('duplicate collection name is rejected in dialog', (tester) async {
      final s = await pumpApp(tester);
      s.library.createCollection('Faves');
      await tapTab(tester, 'Saved');
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'faves');
      await tester.pumpAndSettle();
      expect(find.text('You already have a collection with this name'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(s.library.collections, hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('history list and clear with confirmation', (tester) async {
      final s = await pumpApp(tester);
      s.library
        ..recordView('crush')
        ..recordView('rizz');
      await tapTab(tester, 'Saved');
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Rizz'), findsOneWidget);
      expect(find.text('Crush'), findsOneWidget);
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(s.library.history, hasLength(2));
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(s.library.history, isEmpty);
    });
  });

  group('Shell', () {
    testWidgets('back on a non-home tab returns to Today', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, 'Browse');
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      // ignore: avoid_dynamic_calls
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Flirt Dictionary'), findsOneWidget);
    });

    testWidgets('storage failure shows warning banner', (tester) async {
      final store = MemoryStore()..failWrites = true;
      final s = await pumpApp(tester, store: store);
      expect(find.textContaining('Couldn\'t save'), findsNothing);
      s.library.toggleFavourite('rizz');
      await s.library.flush();
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn\'t save'), findsOneWidget);
    });
  });
}
