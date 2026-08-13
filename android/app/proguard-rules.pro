# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# media_kit / mpv
-keep class com.alexmercerind.** { *; }
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.alexmercerind.**

# just_audio
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# GSON (used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
