# R8 keep rules. Flutter's engine and its plugins ship their own consumer rules;
# these cover the classes that are resolved by name at runtime.

# youtubedl-android loads its bridge from Python over JNI, by string.
-keep class com.yausername.** { *; }

# audio_service names its service and receiver in the manifest, and just_audio
# reaches its session objects by class name.
-keep class com.ryanheise.** { *; }

# Flutter's platform channels call back into these by name.
-keep class io.flutter.plugin.** { *; }
