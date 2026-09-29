# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Gson / JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Dart / platform channels
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Play Core split-install stubs — zinatumika na Flutter engine internally
# lakini hatuzihitaji kwenye APK yetu (tunatoa APK moja tu, sio bundle).
# R8 inalalamika zinapokosekana — tunasimamisha makosa hayo.
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
