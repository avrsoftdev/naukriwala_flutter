import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Ad Unit IDs
  static const String _productionBannerAdUnitId = 'ca-app-pub-7682628416837305/2211932306';

  // App ID (should match AndroidManifest.xml and AdMob console)
  static const String _appId = 'ca-app-pub-7682628416837305~9778926556';

  bool _isInitialized = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Always use production AdUnit ID as requested by user
  String get _bannerAdUnitId => _productionBannerAdUnitId;

  // Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      dev.log('AdMob initialized successfully');
      
      // No test-device IDs: using production AdMob IDs only.
      // If you need to debug in development, use AdMob console test device setup.
    } catch (e) {
      dev.log('Failed to initialize AdMob: $e');
      _isInitialized = false;
    }
  }

  // Create and load a banner ad
  void createBannerAd({
    required AdSize adSize,
    required void Function(Ad) onAdFailedToLoad,
    required void Function(Ad) onAdLoaded,
  }) {
    if (!_isInitialized) {
      dev.log('AdMob not initialized. Call initialize() first.');
      return;
    }

    // Dispose existing banner ad if any
    _bannerAd?.dispose();
    _isBannerAdLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          dev.log('Banner ad loaded successfully');
          _isBannerAdLoaded = true;
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          dev.log('Banner ad failed to load: code=${error.code}, message=${error.message}, domain=${error.domain}');
          _isBannerAdLoaded = false;
          ad.dispose();
          onAdFailedToLoad(ad);
        },
        onAdOpened: (Ad ad) => dev.log('Banner ad opened'),
        onAdClosed: (Ad ad) => dev.log('Banner ad closed'),
        onAdImpression: (Ad ad) => dev.log('Banner ad impression'),
      ),
    );

    _bannerAd!.load();
  }

  // Get the loaded banner ad widget
  Widget? getBannerAdWidget() {
    if (_bannerAd != null && _isBannerAdLoaded) {
      return AdWidget(ad: _bannerAd!);
    }
    return null;
  }

  // Check if banner ad is loaded
  bool get isBannerAdLoaded => _isBannerAdLoaded;

  // Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
    dev.log('Banner ad disposed');
  }

  // Dispose all ads
  void dispose() {
    disposeBannerAd();
    dev.log('All AdMob ads disposed');
  }
}
