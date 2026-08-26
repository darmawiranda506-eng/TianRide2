plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.tianride"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "role"

    productFlavors {
        create("customer") {
            dimension = "role"
            applicationIdSuffix = ".customer"
            versionNameSuffix = "-customer"
        }

        create("driver") {
            dimension = "role"
            applicationIdSuffix = ".driver"
            versionNameSuffix = "-driver"
        }

        create("admin") {
            dimension = "role"
            applicationIdSuffix = ".admin"
            versionNameSuffix = "-admin"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.tianride"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
