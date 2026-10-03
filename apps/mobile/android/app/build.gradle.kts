plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("SAVESTREAM_ANDROID_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("SAVESTREAM_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("SAVESTREAM_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("SAVESTREAM_ANDROID_KEY_PASSWORD")
val admobAppId =
    System.getenv("SAVESTREAM_ADMOB_ANDROID_APP_ID")
        ?: "ca-app-pub-3940256099942544~3347511713"
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
        manifestPlaceholders["admobAppId"] = admobAppId
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

flutter {
    source = "../.."
}
