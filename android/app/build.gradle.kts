import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material comes from android/key.properties (local dev) or
// from environment variables (CI). If neither is present we fall back to the
// debug key so `flutter run --release` still works on a fresh clone — but the
// release workflow refuses to publish a debug-signed APK, so a real release
// can never go out with the Android debug certificate.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val hasReleaseSigning = !releaseStoreFile.isNullOrBlank()

android {
    namespace = "com.taknoghte.taknoghte"
    // Pinned rather than inherited from `flutter.*`: an SDK upgrade must never
    // silently change which devices can install the app.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.taknoghte.taknoghte"
        // Flutter 3.35's engine requires API 24+; a lower value produces an APK
        // that installs and then crashes. 24 is the true floor, not a choice.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFile!!)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
            // v2 + v3 is the complete set at minSdk 24: v1 (JAR signing) only
            // matters below API 24, which this app cannot run on anyway, and
            // AGP drops it regardless. v3 additionally allows key rotation.
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Keep code AND resources intact. The notification icon
            // (ic_stat_dot) is referenced only by a runtime Dart string, so the
            // resource shrinker treated it as unused and dropped it from
            // release — which crashed startup with invalid_icon on some
            // devices. No obfuscation is needed for an offline, open app.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
