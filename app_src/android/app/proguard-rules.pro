# R8 keep rules. Flutter's engine and its plugins ship their own consumer rules;
# these cover the classes that are resolved by name at runtime.

# youtubedl-android loads its bridge from Python over JNI, by string.
-keep class com.yausername.** { *; }

# audio_service names its service and receiver in the manifest, and just_audio
# reaches its session objects by class name.
-keep class com.ryanheise.** { *; }

# Flutter's platform channels call back into these by name.
-keep class io.flutter.plugin.** { *; }

# youtubedl-android extracts its Python runtime with Apache Commons Compress,
# which reaches concrete classes through reflection. R8 merged those classes
# into abstract shells and the extraction died with
# "class g5 is not a concrete class" on a clean install — a crash, not an error.
-keep class org.apache.commons.compress.** { *; }
-keep class com.yausername.youtubedl_common.** { *; }
-keepattributes Exceptions,InnerClasses,*Annotation*,Signature
-dontwarn org.apache.commons.compress.**
-dontwarn org.tukaani.xz.**
