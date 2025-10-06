#########################################
# ✅ Flutter & Android Core
#########################################

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep your app entry points
-keep class **.MainApplication { *; }
-keep class **.MainActivity { *; }

# Keep parcelable classes (used in Flutter channels)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

#########################################
# ✅ Firebase SDKs
#########################################

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.Exclude <fields>;
    @com.google.firebase.database.PropertyName <fields>;
    @com.google.firebase.database.Exclude <fields>;
}

# Firebase Messaging & AppCheck
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class * extends com.google.firebase.appcheck.** { *; }

#########################################
# ✅ Google Play Services & Play Core
#########################################

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ✅ Keep Play Core split install / dynamic feature classes
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.common.** { *; }

-dontwarn com.google.android.play.core.**

#########################################
# ✅ Kotlin & Coroutines
#########################################

-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

#########################################
# ✅ GSON / Serialization
#########################################

-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

#########################################
# ✅ App Models & Public API
#########################################

# Keep all models (adjust your package name if needed)
-keepclassmembers class com.naukariwala.avr.model.** { *; }

# Keep everything public in your package (optional but safer for release builds)
-keep public class com.naukariwala.avr.** { *; }

# Keep constructors for dependency injection
-keepclassmembers class * {
    public <init>(...);
}

#########################################
# ✅ Misc Safe Defaults
#########################################

-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
-dontwarn sun.misc.Unsafe
