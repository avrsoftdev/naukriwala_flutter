# AdMob Banner Ads - Troubleshooting Guide

## ❌ Problem
Banner ads are not showing in the **app bundle release** (production build)
- **Ad Unit ID**: `ca-app-pub-7682628416837305/5508042460`
- **App ID**: `ca-app-pub-7682628416837305~6528563797`

---

## ✅ Current Configuration Status

### Code-Side Setup
- ✅ AdMob SDK initialized in `main.dart`
- ✅ `admob_config.dart` has correct credentials
- ✅ `isTestMode = false` for production
- ✅ Banner ads are created and loaded in both dashboards
- ✅ ProGuard rules updated to protect Google Mobile Ads classes
- ✅ AndroidManifest.xml has correct AdMob App ID

---

## 🔍 Troubleshooting Steps

### Step 1: Add SHA-1 Certificate Fingerprint to AdMob
**This is the #1 most common reason ads don't show!**

#### Get your SHA-1 Fingerprint:

**Option A: From Google Play Store (Recommended for App Bundle)**
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Release** → **Production** (or **Internal Testing**)
4. Click on the app bundle/APK release
5. Scroll down to **App integrity** or **Signing**
6. Copy the **SHA-1 certificate fingerprint**

**Option B: From your local keystore**
```bash
keytool -list -v -keystore android/release.keystore -alias naukariwala_key
```
When prompted, enter the keystore password: `android`

#### Add to AdMob Console:
1. Go to [AdMob Console](https://admob.google.com)
2. Click on your app
3. Go to **App settings**
4. Under **Android package**, add the SHA-1 fingerprint
5. Click **Save**
6. **Wait 15-30 minutes** for changes to propagate

---

### Step 2: Verify Ad Unit Status
1. In [AdMob Console](https://admob.google.com), click your app
2. Check **Ad units**
3. Find your banner ad unit: `ca-app-pub-7682628416837305/5508042460`
4. Verify it shows:
   - ✅ **Status**: "Active" (not "Disabled" or "Approval pending")
   - ✅ **Format**: "Banner"
   - ✅ **No policy violations**

If it shows "Approval pending", you may need to:
- Send more test traffic
- Wait for Google's review (usually 24-48 hours)

---

### Step 3: Ensure App is Published to Play Store
**Important**: The app bundle must be uploaded to Google Play Console for ads to serve properly.

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Release** → **Production** or **Internal Testing**
4. Upload your app bundle
5. Once visible in the store, ads should start showing

**Note**: Test channel (Internal Testing) is fine; you don't need to release to production.

---

### Step 4: Verify App Signing Configuration
Your app must be signed with the same key as registered in AdMob.

**Check signing config:**
```bash
# In android/app/build.gradle.kts
# Release build type should have:
# - signingConfig = signingConfigs.getByName("release")
# - keystore file path and credentials match keystore.properties
```

**Verify keystore.properties:**
```bash
cat android/keystore.properties
```

Output should show:
```properties
storeFile=../release.keystore
storePassword=android
keyAlias=naukariwala_key
keyPassword=android
```

---

### Step 5: Check Test/Debug Mode

**In your code** (`lib/config/admob_config.dart`):
```dart
class AdMobConfig {
  static const String appId = 'ca-app-pub-7682628416837305~6528563797';
  static const String bannerAdUnitId = 'ca-app-pub-7682628416837305/5508042460';
  static const bool isTestMode = false; // ✅ Should be FALSE for production
}
```

**Verify in logs**:
When you run the production app, check logs for:
- ✅ `[AdMob] Using production banner ad unit ID: ca-app-pub-7682628416837305/5508042460`
- ✅ `[AdMob] BannerAd loaded successfully`

If you see test ad unit ID instead, then `isTestMode` or `kDebugMode` is affecting your build.

---

### Step 6: Verify AndroidManifest.xml Configuration
Open `android/app/src/main/AndroidManifest.xml` and verify:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-7682628416837305~6528563797" />
```

This **must match** your AdMob App ID.

---

### Step 7: Check ProGuard Obfuscation
The app bundle uses ProGuard minification. Verify ProGuard rules protect AdMob:

**In `android/app/proguard-rules.pro`:**

```proguard
# ✅ These rules should be present:
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
```

The file has been updated with comprehensive rules. Rebuild your app bundle.

---

### Step 8: Check Ad Load Errors
If you don't see ads, check for load errors in console:

**Look for messages like:**
```
[AdMob] BannerAd failed to load: <error reason>
```

Common error messages:
- `"No ads available"` → Ad inventory issue (wait & retry)
- `"Invalid request"` → Wrong Ad Unit ID
- `"Network error"` → Internet connectivity issue
- `"App state mismatch"` → SHA-1 fingerprint not registered

---

## 🛠️ Rebuild and Test

### Step 1: Clean Build
```bash
flutter clean
cd android
./gradlew clean
cd ..
```

### Step 2: Rebuild App Bundle
```bash
flutter build appbundle --release
```

### Step 3: Upload to Play Store
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to **Release** → **Internal Testing**
4. Click **Create release**
5. Upload your app bundle from `build/app/outputs/bundle/release/app-release.aab`
6. Add release notes and review
7. **Start rollout**

### Step 4: Wait & Test
- Wait 15-30 minutes for changes to propagate
- Download the app from Play Store (Internal Testing channel)
- Run the app and check if ads appear
- Check AdMob console for impressions

---

## 📊 Monitor AdMob Console

After deploying:
1. Go to [AdMob Console](https://admob.google.com)
2. Click your app
3. Check the **Ad unit performance**
4. Look for:
   - Impressions (should increase)
   - Clicks
   - Revenue

---

## 🆘 Still Not Working?

### Verify These Points:
- [ ] SHA-1 fingerprint added to AdMob console
- [ ] Ad unit status is "Active"
- [ ] App bundle uploaded to Play Store
- [ ] `isTestMode = false` in production build
- [ ] `kDebugMode` is false in release builds
- [ ] ProGuard rules are protecting Google Mobile Ads
- [ ] App ID in manifest matches AdMob console

### Check Logs:
Build and run the production app in debug mode:
```bash
flutter run --release
```

Watch console for:
```
[AdMob] Creating banner ad with unit ID: ca-app-pub-7682628416837305/5508042460
[AdMob] BannerAd loaded successfully
```

### Common Fixes:
1. **Wait 24-48 hours** - AdMob needs time to approve and activate new ad units
2. **Send more traffic** - Ad networks need minimum impressions to start serving ads
3. **Check AdMob account** - Verify your account isn't suspended or flagged
4. **Re-register SHA-1** - Delete and re-add the SHA-1 fingerprint in AdMob console

---

## 📚 Additional Resources

- [Google Mobile Ads SDK for Flutter](https://pub.dev/packages/google_mobile_ads)
- [AdMob Help Center](https://support.google.com/admob)
- [Flutter AdMob Integration Guide](https://developers.google.com/admob/flutter/quick-start)

---

**Last Updated**: March 2026
**Status**: Configuration Verified & ProGuard Rules Enhanced
