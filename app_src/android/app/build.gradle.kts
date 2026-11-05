import java.util.Base64
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")

    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.noah.sonarar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.noah.sonarar"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A lite build compiles the download engine out: no CPython runtime, no
    // download UI. Both halves read the SAME --dart-define, read here out of the
    // property Flutter forwards to Gradle, so the APK cannot carry the engine
    // while the Dart side believes it does not (or the other way round).
    val dartDefines: List<String> =
        (project.findProperty("dart-defines") as String?)
            ?.split(",")
            ?.map { encoded: String ->
                try {
                    String(Base64.getDecoder().decode(encoded))
                } catch (e: Exception) {
                    ""
                }
            }
            ?: emptyList()
    val engineLite = dartDefines.contains("SONARAR_DOWNLOADS=false")

    packaging {
        jniLibs {
            // This list is the authority on architectures, not abiFilters: with only
            // abiFilters set, a release build shipped all three ABIs (70.6 MB) and a
            // debug build asking for x86_64 got an APK with no x86_64 libs at all.
            // -PsonararX86 (or ORG_GRADLE_PROJECT_sonararX86=1) keeps x86_64 for
            // emulator builds; release never sets it.
            val allowX86 = (project.findProperty("sonararX86") as String?) == "1"
            excludes += listOf(
                "lib/x86/**",
                "lib/armeabi-v7a/**",
                // 36 MB of ffmpeg for a step the app never runs: the download path
                // asks for one audio stream and keeps its own container. The
                // vendored plugin treats its absence as a capability.
                "lib/arm64-v8a/libffmpeg.zip.so",
                "lib/x86_64/libffmpeg.zip.so",
            )
            if (!allowX86) excludes += listOf("lib/x86_64/**")
            if (engineLite) {
                excludes += listOf("lib/arm64-v8a/libpython.zip.so")
            }
            keepDebugSymbols += listOf("**/libpython.zip.so")

            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            // Emulator and device: the engine's Python payload ships for x86_64 too,
            // so the download path can be exercised without a phone.
            ndk {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Signed only when a key.properties is present: a fresh clone and the
            // store build both stay unsigned, and a release run on this machine signs.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.create("release") {
                    storeFile = file(keystoreProperties.getProperty("storeFile"))
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
