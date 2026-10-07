# SaveStream app entry points referenced by AndroidManifest.xml or Flutter.
# Library plugins are expected to provide their own consumer ProGuard rules.

-keep class com.savestream.app.MainActivity { *; }
-keep class com.savestream.app.LocalRecordingService { *; }
-keep class com.savestream.app.LocalRecordingEventBus { *; }
-keep class com.savestream.app.RecordingPlatformActionEventBus { *; }

# Flutter embedding can resolve the generated registrant by class name.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
