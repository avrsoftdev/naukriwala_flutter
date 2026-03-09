# How to Find SHA-1 Fingerprint in Google Play Console

## 📍 Location: The fingerprint can be in different places depending on your setup

---

## Method 1: Setup > App Signing (Most Common for App Bundles)

### Step-by-Step:
1. Go to **[Google Play Console](https://play.google.com/console)**
2. Select your app (**naukariwala**)
3. In the left menu, go to **Setup** 
4. Click on **App signing** (or **Setup > App integrity**)
5. Look for:
   - **SHA-1 certificate fingerprint** (first line)
   - **SHA-256 certificate fingerprint** (second line)

> ⚠️ **Important**: If you see "UNDER REVIEW" status, you may need to upload an app bundle first.

---

## Method 2: Release > Releases > App bundle details

### Step-by-Step:
1. Go to **Google Play Console**
2. Select your app
3. Go to **Release** → **Production** (or **Internal Testing** / **Alpha** / **Beta**)
4. Under "Releases", find your app bundle release
5. Click on the app bundle (e.g., `app-release.aab`)
6. In the **Details** tab, scroll down to **Signing**
7. Look for:
   - **SHA-1 certificate fingerprint**
   - **SHA-256 certificate fingerprint**

---

## Method 3: Release > Setup > App signing

### Step-by-Step:
1. Go to **Release** in left menu
2. Click on **Setup**
3. Select **App signing** (if available)
4. You should see the fingerprints here

---

## If You CAN'T Find It (Pre-uploaded Apps)

If you haven't uploaded any app bundle yet:

1. You need to **upload your app bundle first**
2. Go to **Release** → **Production** (or Internal Testing)
3. Click **Create release**
4. Upload your app bundle from: `build/app/outputs/bundle/release/app-release.aab`
5. **Don't click "Review release" yet** - just save the draft
6. Once saved, the SHA-1 should appear in the app signing section

---

## If Still Not Visible: Use Gradle Bundlerelease

If Google Play Console still doesn't show it, you can extract it from your app bundle:

```bash
# Navigate to your Flutter project root
cd c:\FlutterProjects\naukariwala

# Build the app bundle (if not already built)
flutter build appbundle --release

# The bundle is created at:
# build/app/outputs/bundle/release/app-release.aab

# To check the signing info, you can use bundletool
# First, download bundletool if you haven't:
# https://developer.android.com/studio/command-line/bundletool

# Then run:
bundletool dump manifest --bundle=build/app/outputs/bundle/release/app-release.aab
```

---

## Quick Checklist:

- [ ] Logged into Google Play Console?
- [ ] Selected the correct app (naukariwala)?
- [ ] Checked **Setup > App signing** first?
- [ ] Checked **Release > Production > App bundle > Signing**?
- [ ] If not found, did you upload an app bundle yet?

---

## Alternative: Get SHA-1 from Your Local Keystore

If you can't find it in Google Play Console, get it directly from your keystore file:

```bash
# From your project root:
cd c:\FlutterProjects\naukariwala\android

keytool -list -v -keystore ../release.keystore -alias naukariwala_key -storepass android -keypass android
```

This will show:
```
Certificate fingerprints:
     SHA1: XX:XX:XX:XX:...
     SHA256: XX:XX:XX:XX:...
```

Copy the **SHA1** value (without colons if needed).

---

## Once You Have the SHA-1:

1. Go to **[AdMob Console](https://admob.google.com)**
2. Click your app
3. Go to **App settings**
4. Under **Android package**, find the SHA-1 fingerprint field
5. Paste your SHA-1 value
6. Click **Save**
7. **Wait 15-30 minutes** for it to take effect

---

## Still Stuck?

Try these Google Play Console locations in this order:

1. **Setup** → **App signing** (Most common)
2. **Release** → **Production** → Your app bundle → Details → Signing
3. **Release** → **Setup** → **App signing** (Alternative path)
4. **Setup** → **App integrity** (Newer console versions)

If none of these work:
- You may need to upload an app bundle first
- Or your Google Play account may have special configuration

---

## Screenshots Help

When looking at Google Play Console, look for a section labeled:
- "App signing certificate"
- "Signing information"  
- "Certificate fingerprints"
- "SHA-1" or "SHA1"

The value looks like: `XX:XX:XX:XX:XX:XX:...` (with colons)

---

**Let me know which method works for you!**
