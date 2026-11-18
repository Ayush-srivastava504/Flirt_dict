import 'package:flirt_dict/app/app.dart';
import 'package:flirt_dict/state/library_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs on a real device/emulator against real SharedPreferences and the
/// real asset bundle: `flutter test integration_test -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  testWidgets('full journey persists across restart', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(const FlirtDictApp());
    await tester.pumpAndSettle();
    stopwatch.stop();
    debugPrint('PERF startup_to_settled_ms=${stopwatch.elapsedMilliseconds}');
    expect(find.text('Flirt Dictionary'), findsOneWidget);

    await tab(tester, 'Search');
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'crush');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('word-crush')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Crush to favourites'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tab(tester, 'Search');
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'flag');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Red Flag'), findsOneWidget);

    // Scroll performance sample on the longest list.
    await tab(tester, 'Browse');
    await tester.tap(find.byKey(const ValueKey('letter-S')));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Restart: rebuild from scratch, reading real persisted storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const FlirtDictApp(key: ValueKey('second-launch')));
    await tester.pumpAndSettle();
    final stored = (await SharedPreferences.getInstance()).getStringList(
      LibraryController.favouritesKey,
    );
    expect(stored, ['crush']);
    await tab(tester, 'Saved');
    expect(find.text('Crush'), findsOneWidget);
  });
}
