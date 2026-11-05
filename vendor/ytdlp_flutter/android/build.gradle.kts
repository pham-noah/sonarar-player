group = "se.cstate.ytdlp_flutter"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "se.cstate.ytdlp_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Bundled Python + yt-dlp (runtime-updatable) + FFmpeg for -x extraction.
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    // SharedPrefsHelper lives in `common`, which `library` declares as
    // `implementation`, so it is not on this module's compile classpath. Declared
    // here because this plugin writes the python payload's staleness marker.
    implementation("io.github.junkfood02.youtubedl-android:common:0.18.1")
    // ZipInputStream writes a symlink as a file holding its target path, which is
    // how Python's zlib ends up 13 bytes long and unable to load. Commons Compress
    // reads the unix mode so links can be recreated.
    implementation("org.apache.commons:commons-compress:1.26.2")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
