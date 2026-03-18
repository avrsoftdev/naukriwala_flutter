// This file contains AdMob configuration
// DO NOT commit this file to version control

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdMobConfig {
  // Load environment variables
  static bool _isInitialized = false;

  static void _ensureInitialized() {
    if (!_isInitialized) {
      // These will be loaded from .env file in production
      // Fallback to test values if .env is not available (development)
      _isInitialized = true;
    }
  }

  // AdMob App ID from environment or fallback
  static String get appId {
    _ensureInitialized();
    return dotenv.env['ADMOB_APP_ID'] ?? 
           'ca-app-pub-3940256099942544~3347511713'; // Test App ID
  }

  // Banner Ad Unit ID from environment or fallback
  static String get bannerAdUnitId {
    _ensureInitialized();
    return dotenv.env['ADMOB_BANNER_UNIT_ID'] ?? 
           'ca-app-pub-3940256099942544/6300978111'; // Test Banner ID
  }

  // Interstitial Ad Unit ID (optional)
  static String? get interstitialAdUnitId {
    _ensureInitialized();
    return dotenv.env['ADMOB_INTERSTITIAL_UNIT_ID'];
  }

  // Rewarded Ad Unit ID (optional)
  static String? get rewardedAdUnitId {
    _ensureInitialized();
    return dotenv.env['ADMOB_REWARDED_UNIT_ID'];
  }

  // Test mode from environment or fallback
  static bool get isTestMode {
    _ensureInitialized();
    final testMode = dotenv.env['IS_TEST_MODE'];
    if (testMode != null) {
      return testMode.toLowerCase() == 'true';
    }
    // Default to true for development if not specified
    return true;
  }

  // Check if we're using real AdMob IDs (production)
  static bool get isUsingProductionIds {
    _ensureInitialized();
    return !isTestMode && 
           appId.contains('7682628416837305') && 
           bannerAdUnitId.contains('7682628416837305');
  }

  // For debugging - show current configuration (without exposing sensitive IDs)
  static Map<String, dynamic> getConfigInfo() {
    _ensureInitialized();
    return {
      'hasAppId': dotenv.env['ADMOB_APP_ID'] != null,
      'hasBannerId': dotenv.env['ADMOB_BANNER_UNIT_ID'] != null,
      'isTestMode': isTestMode,
      'isProduction': isUsingProductionIds,
      'appIdPrefix': appId.substring(0, 20) + '...',
      'bannerIdPrefix': bannerAdUnitId.substring(0, 20) + '...',
    };
  }
}
