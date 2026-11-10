# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }

# SQLite3 / Drift native libs
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Timezone
-keep class com.whelksoftware.flutter_timezone.** { *; }
-keep class net.jonhanson.flutter_native_timezone.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Google Play Core split install warnings suppression
-dontwarn com.google.android.play.core.**
