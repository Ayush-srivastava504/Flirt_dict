import 'package:flirt_dict/ui/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Runs Flutter's built-in accessibility guideline checks (touch target
/// size, labelled tappables, text contrast) on every main screen, in light
/// and dark themes.
void main() {
  setUp(resetNavigationCooldown);

  Future<void> checkAll(WidgetTester tester, String screen) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: screen);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: screen);
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: screen);
  }

  for (final brightness in Brightness.values) {
    testWidgets('screens meet a11y guidelines (${brightness.name})', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final handle = tester.ensureSemantics();
      final s = await pumpApp(tester);
      s.library
        ..toggleFavourite('rizz')
        ..recordView('crush')
        ..createCollection('Faves', initialWordId: 'rizz');
      await tester.pumpAndSettle();

      await checkAll(tester, 'Today');

      await tapTab(tester, 'Browse');
      await checkAll(tester, 'Browse');
      await tester.tap(find.byKey(const ValueKey('letter-G')));
      await tester.pumpAndSettle();
      await checkAll(tester, 'Letter');
      await scrollToWordInLetter(tester, 'Ghosting');
      await scrollToWordInLetter(tester, 'Ghosting');
    await tester.tap(find.text('Ghosting'));
      await tester.pumpAndSettle();
      await checkAll(tester, 'Word detail');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapTab(tester, 'Search');
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'love');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await checkAll(tester, 'Search');

      await tapTab(tester, 'Saved');
      await checkAll(tester, 'Saved');
      handle.dispose();
    });
  }

  testWidgets('icon-only buttons have semantic labels', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await tapTab(tester, 'Browse');
    await tester.tap(find.byKey(const ValueKey('letter-G')));
    await tester.pumpAndSettle();
    // IconButton tooltips are exposed to TalkBack as the semantic tooltip.
    final fav = tester.getSemantics(find.byTooltip('Add Ghosting to favourites'));
    expect(fav.tooltip, 'Add Ghosting to favourites');
    await scrollToWordInLetter(tester, 'Ghosting');
    await tester.tap(find.text('Ghosting'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byTooltip('Share')).tooltip, 'Share');
    // A–Z cells announce their word counts (singular for one word).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('X, 1 word'), findsOneWidget);
    handle.dispose();
  });
}
