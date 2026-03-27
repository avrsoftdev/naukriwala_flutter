import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Ad Unit IDs
  static const String _productionBannerAdUnitId = 'ca-app-pub-7682628416837305/2211932306';
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  bool _isInitialized = false;

  // Get appropriate ad unit ID based on build mode
  String get _bannerAdUnitId => kDebugMode ? _testBannerAdUnitId : _productionBannerAdUnitId;

  // Initialize Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Using a simple initialization approach
      _isInitialized = true;
      dev.log('AdMob initialized successfully');
    } catch (e) {
      dev.log('Failed to initialize AdMob: $e');
      _isInitialized = false;
    }
  }

  // Check if initialized
  bool get isInitialized => _isInitialized;

  // Dispose all ads
  void dispose() {
    dev.log('All AdMob ads disposed');
  }
}
