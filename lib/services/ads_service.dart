import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  /// Initialize Google Mobile Ads SDK and load environment variables
  /// Should be called in main() before runApp()
  static Future<void> initializeAds() async {
    try {
      // Load environment variables from .env file
      await dotenv.load(fileName: '.env');
      print('[AdMob] Environment variables loaded successfully');
      
      // Print configuration info (without exposing sensitive data)
      final configInfo = AdMobConfig.getConfigInfo();
      print('[AdMob] Configuration: $configInfo');
      
      // Initialize Google Mobile Ads SDK
      await MobileAds.instance.initialize();
      print('[AdMob] Google Mobile Ads SDK initialized successfully');
      print('[AdMob] Using AdMob App ID: ${AdMobConfig.appId.substring(0, 20)}...');
    } catch (e) {
      print('[AdMob] Error initializing Google Mobile Ads: $e');
      print('[AdMob] Falling back to test configuration');
      // Don't rethrow - allow app to continue without ads
    }
  }

  /// Get the appropriate banner ad unit ID
  /// Uses environment variables and configuration to determine the right ad unit
  static String getAdUnitId() {
    final adUnitId = AdMobConfig.bannerAdUnitId;
    print('[AdMob] Getting ad unit ID: ${adUnitId.substring(0, 20)}...');
    print('[AdMob] Test mode: ${AdMobConfig.isTestMode}');
    print('[AdMob] Debug mode: $kDebugMode');
    
    return adUnitId;
  }

  /// Create a BannerAd widget
  static BannerAd createBannerAd() {
    final adUnitId = getAdUnitId();
    print('[AdMob] Creating banner ad with unit ID: $adUnitId');
    print('[AdMob] Full ad unit ID: $adUnitId');
    print('[AdMob] App ID: ${AdMobConfig.appId}');
    print('[AdMob] Is test mode: ${AdMobConfig.isTestMode}');
    print('[AdMob] Is debug mode: $kDebugMode');

    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        nonPersonalizedAds: false,
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('[AdMob] ✅ BannerAd loaded successfully!');
          print('[AdMob] Ad unit ID: ${ad.adUnitId}');
        },
        onAdFailedToLoad: (ad, error) {
          print('[AdMob] ❌ BannerAd failed to load: ${error.code}');
          print('[AdMob] ❌ Error message: ${error.message}');
          print('[AdMob] ❌ Full error: $error');
          print('[AdMob] ❌ Ad unit ID that failed: $adUnitId');
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
