import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';

class AdsService {
  // AdMob IDs from config
  static String get admobAppId => AdMobConfig.appId;
  static String get bannerAdUnitId => AdMobConfig.bannerAdUnitId;

  // Test IDs (for development/testing on local machine)
  // Google provides test ad unit IDs for safe testing
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static final AdsService _instance = AdsService._internal();

  AdsService._internal();

  factory AdsService() {
    return _instance;
  }

  /// Initialize Google Mobile Ads SDK
  /// Should be called in main() before runApp()
  static Future<void> initializeAds() async {
    try {
      await MobileAds.instance.initialize();
      print('[AdMob] Google Mobile Ads SDK initialized successfully');
    } catch (e) {
      print('[AdMob] Error initializing Google Mobile Ads: $e');
      // Don't rethrow - allow app to continue without ads
    }
  }

  /// Get the appropriate banner ad unit ID
  /// In debug mode (local development), returns Google's test ad unit ID
  /// In release mode (APK/production), returns your production ad unit ID
  static String getAdUnitId() {
    if (kDebugMode || AdMobConfig.isTestMode) {
      return testBannerAdUnitId;
    } else {
      // Use your actual AdMob unit ID for production/APK builds
      print('[AdMob] Using production banner ad unit ID: $bannerAdUnitId');
      return bannerAdUnitId;
    }
  }

  /// Create a BannerAd widget
  static BannerAd createBannerAd() {
    final adUnitId = getAdUnitId();
    print('[AdMob] Creating banner ad with unit ID: $adUnitId');

    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('[AdMob] BannerAd loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('[AdMob] BannerAd failed to load: ${error.message}');
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('[AdMob] BannerAd opened');
        },
        onAdClosed: (ad) {
          print('[AdMob] BannerAd closed');
        },
        onAdImpression: (ad) {
          print('[AdMob] BannerAd impression recorded');
        },
      ),
    );
  }
}
