#########################################
# ✅ Flutter & Android Core
#########################################
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
# Keep Flutter Google Mobile Ads plugin
-keep class com.google.android.gms.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
# Keep app entry points and potential services
-keep class **.MainApplication { *; }
-keep class **.MainActivity { *; }
-keep class * extends android.app.Service { *; }
# Keep parcelable classes (used in Flutter channels)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
#########################################
# ✅ Firebase SDKs
#########################################
# Keep only used Firebase services
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.appcheck.** { *; }
-dontwarn com.google.firebase.**
# Keep Firestore and Realtime Database annotations
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.Exclude <fields>;
    @com.google.firebase.database.PropertyName <fields>;
    @com.google.firebase.database.Exclude <fields>;
}
# Keep FCM and App Check services
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class * extends com.google.firebase.appcheck.** { *; }
#########################################
# ✅ Google Play Services & Play Core
#########################################
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

#########################################
# ✅ Google Mobile Ads (AdMob)
#########################################
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**
-keep public class com.google.android.gms.ads.AdManager { public *; }
-keep class * extends com.google.android.gms.ads.AdListener { *; }
-keep class * extends com.google.android.gms.ads.reward.RewardedVideoAdListener { *; }
-keep interface com.google.android.gms.ads.reward.RewardedVideoAdListener { *; }
# Keep AdView and BannerAdListener
-keep class com.google.android.gms.ads.AdView { *; }
-keep class com.google.android.gms.ads.BaseAdView { *; }
-keepclassmembers class * {
    *** onAdLoaded(...);
    *** onAdFailedToLoad(...);
    *** onAdOpened(...);
    *** onAdClosed(...);
    *** onAdClicked(...);
    *** onAdImpression(...);
}
# Keep Play Integrity classes
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**
# Keep Play Core split install and app update classes
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-keep class com.google.android.play.core.appupdate.** { *; }
-dontwarn com.google.android.play.core.**
#########################################
# ✅ Kotlin & Coroutines
#########################################
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**
#########################################
# ✅ App Models & Public API
#########################################
# Keep specific model package (adjust if package name differs)
-keepclassmembers class com.naukariwala.avr.model.** { *; }
# Keep public classes in your app package
-keep public class com.naukariwala.avr.** { *; }
# Keep constructors for dependency injection or instantiation
-keepclassmembers class * {
    public <init>(...);
}
# Keep custom exception class
-keep class com.naukariwala.avr.AuthException { *; }
#########################################
# ✅ Misc Safe Defaults
#########################################
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
-dontwarn sun.misc.Unsafe
# Prevent removal of MultiDex-related classes
-keep class androidx.multidex.** { *; }
-dontwarn androidx.multidex.**