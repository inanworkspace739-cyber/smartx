import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  // App Open Ad
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;
  bool _isFirstAdLoad = true;

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoaded = false;

  // Rewarded Ad
  RewardedAd? _rewardedAd;
  bool _isRewardedLoaded = false;

  /// Production App Open Ad Unit IDs
  String get adUnitId {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'ca-app-pub-9283129936552011/3099631235';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Production Interstitial Ad Unit IDs
  String get interstitialAdUnitId {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'ca-app-pub-9283129936552011/7151552730';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Production Rewarded Ad Unit ID
  String get rewardedAdUnitId {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'ca-app-pub-9283129936552011/6374226872';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Load an AppOpenAd.
  void loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoadTime = DateTime.now();
          _appOpenAd = ad;
          if (_isFirstAdLoad) {
            _isFirstAdLoad = false;
            showAppOpenAdIfAvailable();
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  /// Whether an ad is available to be shown.
  bool get isAppOpenAdAvailable {
    return _appOpenAd != null;
  }

  /// Shows the AppOpenAd, if one exists and is not already being shown.
  void showAppOpenAdIfAvailable() {
    if (!isAppOpenAdAvailable) {
      debugPrint('Tried to show app open ad before available.');
      loadAppOpenAd();
      return;
    }
    if (_isShowingAd) {
      debugPrint('Tried to show app open ad while already showing an ad.');
      return;
    }
    if (DateTime.now()
        .subtract(const Duration(hours: 4))
        .isAfter(_appOpenLoadTime!)) {
      debugPrint(
        'Maximum cache duration exceeded. Loading another app open ad.',
      );
      _appOpenAd!.dispose();
      _appOpenAd = null;
      loadAppOpenAd();
      return;
    }

    // Set the fullScreenContentCallback and show the ad.
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        debugPrint('$ad onAdShowedFullScreenContent');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('$ad onAdDismissedFullScreenContent');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );
    _appOpenAd!.show();
  }

  // ═══════════════════════════════════════════
  // INTERSTITIAL ADS
  // ═══════════════════════════════════════════

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialLoaded = false;
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _isShowingAd = true; // prevent app open ad from showing right after
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _isShowingAd = false;
          ad.dispose();
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _isShowingAd = false;
          ad.dispose();
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdClosed?.call();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      onAdClosed?.call();
    }
  }

  // ═══════════════════════════════════════════
  // REWARDED ADS
  // ═══════════════════════════════════════════

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedLoaded = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad. [onRewarded] fires when the user earns the reward.
  /// [onClosed] fires when the ad is dismissed (whether rewarded or not).
  void showRewardedAd({VoidCallback? onRewarded, VoidCallback? onClosed}) {
    if (_isRewardedLoaded && _rewardedAd != null) {
      _isShowingAd = true;
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _isShowingAd = false;
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd();
          onClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _isShowingAd = false;
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd();
          onClosed?.call();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) => onRewarded?.call());
      _rewardedAd = null;
    } else {
      // Ad not ready — load for next time and proceed anyway
      loadRewardedAd();
      onClosed?.call();
    }
  }
}

/// Listens for app state changes and shows the app open ad when appropriate.
class AppLifecycleReactor {
  final AdManager adManager;

  AppLifecycleReactor({required this.adManager});

  void listenToAppStateChanges() {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.forEach(
      (state) => _onAppStateChanged(state),
    );
  }

  void _onAppStateChanged(AppState appState) {
    if (appState == AppState.foreground) {
      adManager.showAppOpenAdIfAvailable();
    }
  }
}
