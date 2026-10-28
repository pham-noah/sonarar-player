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
    namespace = "com.noah.personar"
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

    packaging {
        jniLibs {
            excludes += listOf(
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/armeabi-v7a/**",
            )
            keepDebugSymbols += listOf("**/libpython.zip.so", "**/libffmpeg.zip.so")

            useLegacyPackaging = true
        }
    }

    buildTypes {
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
