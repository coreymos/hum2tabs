plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin last
}

android {
    namespace  = "com.example.hum2tabs"

    compileSdk = 35                        // Android 15
    ndkVersion = "29.0.13113456-rc1"       // match your installed NDK folder

    defaultConfig {
        applicationId = "com.example.hum2tabs"

        minSdk      = 24                  // required by flutter_sound 9.x & permission_handler 12.x
        targetSdk   = 35

        versionCode = 1
        versionName = "1.0.0"
    }

    /* Java / Kotlin tool-chain */
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }

    /* Build types */
    buildTypes {
        // Debug build: no shrinking for quick hot-reload
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        // Release build: R8 + resource shrink
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true            // <-- Kotlin DSL setter
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")  // TODO replace with real keystore
        }
    }
}

flutter {
    source = "../.."    // path back to project root
}
