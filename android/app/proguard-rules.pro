# 🔐 Digital Diary - ProGuard Rules for Security

# ============================================
# FLUTTER CORE - DO NOT MODIFY
# ============================================
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-dontwarn io.flutter.**

# ============================================
# FLUTTER PIGEON - CRITICAL FOR PLATFORM CHANNELS
# ============================================
-keep class dev.flutter.pigeon.** { *; }
-keep class ** implements dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }
-dontwarn dev.flutter.pigeon.**

# Keep all classes that end with HostApi or FlutterApi (Pigeon generated)
-keep class **HostApi { *; }
-keep class **FlutterApi { *; }
-keep class **.*HostApi { *; }
-keep class **.*FlutterApi { *; }

# ============================================
# FIREBASE - ALL MODULES
# ============================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class com.google.firebase.** { *; }
-keepclassmembers class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase plugins for Flutter
-keep class io.flutter.plugins.firebase.** { *; }
-keepclassmembers class io.flutter.plugins.firebase.** { *; }

# ============================================
# GOOGLE PLAY SERVICES
# ============================================
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google Play Billing
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.vending.billing.**

# ============================================
# KOTLIN
# ============================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ============================================
# NATIVE CODE
# ============================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# App specific native config
-keep class com.dincerefe.digitaldiary.** { *; }
-keepclassmembers class com.dincerefe.digitaldiary.** { *; }

# ============================================
# MEDIA & CAMERA
# ============================================
-keep class androidx.camera.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.arthenica.** { *; }
-dontwarn androidx.camera.**
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**
-dontwarn com.arthenica.**

# ============================================
# NETWORKING
# ============================================
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep class io.grpc.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn io.grpc.**

# ============================================
# JSON & SERIALIZATION
# ============================================
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ============================================
# DEBUGGING
# ============================================
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ============================================
# DISABLE AGGRESSIVE OPTIMIZATIONS
# ============================================
-dontoptimize
-dontobfuscate
