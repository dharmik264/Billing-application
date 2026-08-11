# Flutter & Android ProGuard Security Hardening Rules

# Keep Flutter Engine & Plugin classes
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep MainActivity
-keep class com.dharmik.billingapp.MainActivity { *; }

# Obfuscation & Shrinking Settings
-repackageclasses ''
-allowaccessmodification
-dontusemixedcaseclassnames

# Strip sensitive debugging log calls in production build
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Preserve generic signatures and annotations required by plugins/JSON serializing
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Do not warn on Flutter dynamic features or optional dependency classes
-dontwarn io.flutter.**
-dontwarn com.google.crypto.tink.**
-dontwarn javax.annotation.**
