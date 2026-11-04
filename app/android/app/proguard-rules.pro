# R8 rules for release builds. Flutter's Gradle plugin adds the engine rules.
# Plugins used here ship their own consumer rules (mobile_scanner/ML Kit,
# flutter_secure_storage, file_picker, flutter_web_auth_2); these are only
# safety nets for reflection-based lookups.
-keep class com.linusu.flutter_web_auth_2.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.android.play.core.**
