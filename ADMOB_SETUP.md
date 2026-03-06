# AdMob Configuration Setup

## Current Implementation

The app now uses a secure configuration file approach for AdMob credentials:

### Files Involved:
- `lib/config/admob_config.dart` - Contains AdMob credentials (NOT committed to Git)
- `lib/services/ads_service.dart` - Uses the config for ad initialization
- `.gitignore` - Excludes the config directory from version control

### Setup Instructions

1. **The config file is already created** at `lib/config/admob_config.dart`
2. **Edit the config file** with your actual AdMob credentials if needed:
   ```dart
   class AdMobConfig {
     static const String appId = 'your_admob_app_id_here';
     static const String bannerAdUnitId = 'your_banner_unit_id_here';
     static const bool isTestMode = true; // Set to false for production
   }
   ```

3. **For production builds:**
   - Set `isTestMode = false` in `admob_config.dart`
   - Ensure your AdMob app ID and unit IDs are correct

### Important Security Notes

- The `lib/config/` directory is added to `.gitignore` and will NOT be committed to GitHub
- Never commit actual AdMob credentials to version control
- For production builds, ensure the AdMob app ID in `android/app/src/main/AndroidManifest.xml` matches your config
- Test ads will be shown during development (when `isTestMode = true`)
- Real ads will be shown in production APK builds (when `isTestMode = false`)

### AndroidManifest.xml

The AdMob app ID is hardcoded in `android/app/src/main/AndroidManifest.xml` for Android builds. Make sure this matches your `admob_config.dart` file for production builds.