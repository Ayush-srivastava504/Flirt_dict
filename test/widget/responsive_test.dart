import 'package:flirt_dict/ui/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Visits every screen at a range of device sizes and font scales. Any
/// RenderFlex overflow or layout exception fails the test.
void main() {
  setUp(resetNavigationCooldown);

  const sizes = <String, Size>{
    'small phone 320x568': Size(320, 568),
    'standard phone 412x915': Size(412, 915),
    'landscape phone 915x412': Size(915, 412),
    'tablet 800x1280': Size(800, 1280),
  };
  const scales = [1.0, 1.5, 2.0];

  for (final size in sizes.entries) {
    for (final scale in scales) {
      testWidgets('all screens render at ${size.key}, text x$scale', (tester) async {
        final s = await pumpApp(tester, size: size.value, textScale: scale);
        s.library
          ..toggleFavourite('rizz')
          ..recordView('crush')
          ..createCollection('A very long collection name for testing!', initialWordId: 'rizz');
        await tester.pumpAndSettle();

        // Today (scroll through whole page).
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();

        // Browse + letter + category.
        await tapTab(tester, 'Browse');
        await tester.tap(find.byKey(const ValueKey('letter-S')));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Word detail with the most content.
        resetNavigationCooldown();
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        openWord(nav.context, 'wear-your-heart-on-your-sleeve');
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        resetNavigationCooldown();
        openWord(nav.context, 'limerence');
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Search with results and with no results.
        await tapTab(tester, 'Search');
        await tester.enterText(find.byKey(const ValueKey('search-field')), 'love');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('search-field')), 'ghostng');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Saved tabs.
        await tapTab(tester, 'Saved');
        await tester.tap(find.text('Collections'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('dark theme renders without errors', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    final ctx = tester.element(find.text('Flirt Dictionary'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
