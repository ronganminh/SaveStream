# SaveStream release R8 rules.
# Flutter/Firebase/Google Mobile Ads ship consumer rules; keep only app/native
# entry points and Flutter plugin registrants that are referenced reflectively.

-keep class com.savestream.app.MainActivity { *; }
-keep class com.savestream.app.LocalRecordingService { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Firebase Messaging can instantiate service/plugin classes through Android
# manifest and plugin registration paths.
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# Preserve annotation metadata used by platform SDKs.
-keepattributes *Annotation*
