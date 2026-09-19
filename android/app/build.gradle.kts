plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drugsia.app.drugs_ia_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Doit correspondre au package enregistré dans le projet Firebase
        // "drugs-d1e2b" (App Distribution rejette tout APK dont le nom de
        // paquet ne correspond pas exactement à celui de l'app Firebase).
        applicationId = "com.drugs"
        // Android 12 (API 31) minimum, comme demandé — pas de support des
        // versions antérieures. Les APK de release incluent nativement
        // armeabi-v7a (32-bit) + arm64-v8a (64-bit) + x86_64 tant qu'on ne
        // passe pas --split-per-abi au build.
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
