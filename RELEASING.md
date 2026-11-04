# Release builds

`android/key.properties` is not tracked and must point at the signing keystore
relative to `android/app`, which is how Gradle resolves it:

    storeFile=../../../../Sonarar-release/release.jks

An absolute path here does not survive moving the projects folder, and the failure is
late: Gradle reaches `:app:validateSigningRelease` after several minutes of building.

`kotlin.incremental=false` in `android/gradle.properties` is deliberate: the Kotlin
daemon cannot close its incremental caches for two plugin modules on this tree, and a
release build has to be repeatable more than it has to be fast.
