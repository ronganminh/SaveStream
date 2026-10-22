plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseKeystorePath = System.getenv("SAVESTREAM_ANDROID_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("SAVESTREAM_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("SAVESTREAM_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("SAVESTREAM_ANDROID_KEY_PASSWORD")
// AdMob app id comes from the build environment (the release workflow sets
// the production id); without it, and in debug/profile builds, Google's
// sample app id is used so local runs never hit the production account.
val admobAppId =
    System.getenv("SAVESTREAM_ADMOB_ANDROID_APP_ID")?.takeIf { it.isNotBlank() }
val testAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val hasReleaseSigning =
    !releaseKeystorePath.isNullOrBlank() &&
    !releaseKeystorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.savestream.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.savestream.app"
        minSdk = 24
        manifestPlaceholders["admobAppId"] = testAdmobAppId
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            manifestPlaceholders["admobAppId"] = admobAppId ?: testAdmobAppId
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    // Google Mobile Ads pulls WorkManager 2.7.0 transitively. Its bundled
    // Room 2.2.5 database fails during startup after AGP 9/R8 optimization,
    // so keep the AndroidX runtime current (the boot receiver and foreground
    // service permissions it merges are removed in AndroidManifest.xml).
    implementation("androidx.work:work-runtime:2.12.0")
}

flutter {
    source = "../.."
}
