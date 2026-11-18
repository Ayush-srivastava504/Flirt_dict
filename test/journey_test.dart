import 'package:flirt_dict/data/local_store.dart';
import 'package:flirt_dict/state/library_controller.dart';
import 'package:flirt_dict/ui/navigation.dart';
import 'package:flirt_dict/ui/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// End-to-end user journey on the host, with an app "restart" simulated by
/// tearing down the widget tree and booting again from the same store.
void main() {
  setUp(resetNavigationCooldown);

  testWidgets('launch → browse → favourite → search → collect → restart', (tester) async {
    final store = MemoryStore();

    // ---- Session 1
    var s = await pumpApp(tester, store: store);
    await tapTab(tester, 'Browse');
    await tester.tap(find.byKey(const ValueKey('letter-R')));
    await tester.pumpAndSettle();
    await scrollToWordInLetter(tester, 'Rizz');
    await tester.tap(find.text('Rizz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Rizz to favourites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gen Z');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // dismiss sheet
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapTab(tester, 'Search');
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'ghost');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('word-ghosting')));
    await tester.pumpAndSettle();
    await s.library.flush();

    // ---- "Kill" the app and relaunch from the same storage.
    await tester.pumpWidget(const SizedBox());
    resetNavigationCooldown();
    s = await pumpApp(tester, store: store);

    expect(s.library.favourites, ['rizz']);
    expect(s.library.collections.single.name, 'Gen Z');
    expect(s.library.collections.single.wordIds, ['rizz']);
    expect(s.library.history.take(2), ['ghosting', 'rizz']);
    expect(s.library.recentSearches, ['ghost']);

    await tester.scrollUntilVisible(
      find.text('Recently viewed'),
      300,
      scrollable: find
          .descendant(of: find.byType(TodayScreen), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Recently viewed'), findsOneWidget);
    await tapTab(tester, 'Saved');
    expect(find.text('Rizz'), findsOneWidget);
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(find.text('Gen Z'), findsOneWidget);
  });

  testWidgets('launch with corrupt stored data still works', (tester) async {
    final store = MemoryStore({
      LibraryController.collectionsKey: '}}}corrupt',
      LibraryController.favouritesKey: ['no-such-word', 'crush'],
      LibraryController.historyKey: 12345,
    });
    final s = await pumpApp(tester, store: store);
    expect(s.library.favourites, ['crush']);
    expect(find.text('Flirt Dictionary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
