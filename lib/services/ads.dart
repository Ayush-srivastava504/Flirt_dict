import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/log.dart';

/// Interstitial ad policy for the app.
abstract class Ads {
  /// Gathers consent (EEA/UK) and initialises the SDK. Never throws.
  Future<void> initialize();

  /// Called each time the user opens a word. Shows an interstitial only when
  /// the frequency rules allow it; otherwise does nothing.
  void onWordOpened();

  /// Whether the user must be offered a way to change ad privacy choices.
  Future<bool> get privacyOptionsRequired;

  /// Re-opens the consent form so the user can change their choices.
  Future<void> showPrivacyOptions();
}

class NoopAds implements Ads {
  const NoopAds();
  @override
  Future<void> initialize() async {}
  @override
  void onWordOpened() {}
  @override
  Future<bool> get privacyOptionsRequired async => false;
  @override
  Future<void> showPrivacyOptions() async {}
}

/// Frequency rules, kept separate from the SDK so they can be unit tested.
class InterstitialPolicy {
  InterstitialPolicy({
    DateTime Function()? clock,
    this.minInterval = const Duration(minutes: 3),
    this.wordsBeforeFirstAd = 4,
    this.wordsBetweenAds = 4,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration minInterval;

  /// No ad until the user has opened this many words this session.
  final int wordsBeforeFirstAd;

  /// And at least this many words between ads.
  final int wordsBetweenAds;

  int _wordsSinceLastAd = 0;
  bool _shownThisSession = false;
  DateTime? _lastShown;

  /// Records a word open; returns true if an ad may be shown now.
  bool registerWordOpen() {
    _wordsSinceLastAd++;
    final needed = _shownThisSession ? wordsBetweenAds : wordsBeforeFirstAd;
    if (_wordsSinceLastAd < needed) return false;
    final last = _lastShown;
    if (last != null && _clock().difference(last) < minInterval) return false;
    return true;
  }

  void markShown() {
    _shownThisSession = true;
    _lastShown = _clock();
    _wordsSinceLastAd = 0;
  }
}

class AdMobAds implements Ads {
  AdMobAds({InterstitialPolicy? policy}) : _policy = policy ?? InterstitialPolicy();

  /// Production interstitial unit. Debug/profile builds always use Google's
  /// official test unit so the developer never clicks live ads.
  static const String _releaseInterstitialId = 'ca-app-pub-5594205569635986/7307711501';
  static const String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static String get interstitialUnitId =>
      kReleaseMode ? _releaseInterstitialId : _testInterstitialId;

  final InterstitialPolicy _policy;
  InterstitialAd? _ad;
  bool _loading = false;
  bool _ready = false;
  int _loadFailures = 0;

  @override
  Future<void> initialize() async {
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) {
        logDebug('Ads: consent does not allow requesting ads');
        return;
      }
      await MobileAds.instance.initialize();
      _ready = true;
      _load();
    } catch (e) {
      logDebug('Ads init failed: $e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) logDebug('Consent form error: ${error.message}');
        if (!done.isCompleted) done.complete();
      }),
      (FormError error) {
        logDebug('Consent update error: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    // Never block ads (or the app) forever on a consent network call.
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  void _load() {
    if (!_ready || _loading || _ad != null || _loadFailures >= 3) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _loadFailures = 0;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _loadFailures++;
          logDebug('Interstitial failed to load: ${error.code} ${error.message}');
        },
      ),
    );
  }

  @override
  void onWordOpened() {
    if (!_ready) return;
    // Count every open, even while no ad is loaded, so the cap stays accurate.
    if (!_policy.registerWordOpen()) {
      _load();
      return;
    }
    final ad = _ad;
    if (ad == null) {
      _load();
      return;
    }
    _ad = null;
    _policy.markShown();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        logDebug('Interstitial failed to show: ${error.message}');
        ad.dispose();
        _load();
      },
    );
    ad.show();
  }

  @override
  Future<bool> get privacyOptionsRequired async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) logDebug('Privacy options error: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
