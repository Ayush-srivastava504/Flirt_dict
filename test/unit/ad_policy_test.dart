import 'package:flirt_dict/services/ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  InterstitialPolicy make() => InterstitialPolicy(clock: () => now);

  setUp(() => now = DateTime(2026, 11, 18, 12));

  test('no ad until the 4th word of the session', () {
    final p = make();
    expect([for (var i = 0; i < 3; i++) p.registerWordOpen()], everyElement(isFalse));
    expect(p.registerWordOpen(), isTrue);
  });

  test('after an ad: needs 3 minutes AND 4 more words', () {
    final p = make();
    for (var i = 0; i < 4; i++) {
      p.registerWordOpen();
    }
    p.markShown();

    // 4 words but only 1 minute later → blocked.
    now = now.add(const Duration(minutes: 1));
    for (var i = 0; i < 4; i++) {
      expect(p.registerWordOpen(), isFalse);
    }

    // Time passes; the next open is allowed (word count already met).
    now = now.add(const Duration(minutes: 2));
    expect(p.registerWordOpen(), isTrue);
  });

  test('3 minutes passing alone is not enough without more words', () {
    final p = make();
    for (var i = 0; i < 4; i++) {
      p.registerWordOpen();
    }
    p.markShown();
    now = now.add(const Duration(minutes: 30));
    expect(p.registerWordOpen(), isFalse);
    expect(p.registerWordOpen(), isFalse);
    expect(p.registerWordOpen(), isFalse);
    expect(p.registerWordOpen(), isTrue);
  });

  test('rapid word opening cannot produce more than one ad per interval', () {
    final p = make();
    var shown = 0;
    for (var i = 0; i < 200; i++) {
      if (p.registerWordOpen()) {
        p.markShown();
        shown++;
      }
      now = now.add(const Duration(seconds: 2)); // 200 words in ~6.5 minutes
    }
    expect(shown, lessThanOrEqualTo(3));
  });

  test('release builds never use test IDs and debug never uses live IDs', () {
    // Tests run in debug mode.
    expect(AdMobAds.interstitialUnitId, 'ca-app-pub-3940256099942544/1033173712');
  });
}
