plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.appbanco_losandes_ventas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.appbanco_losandes_ventas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val mapsApiKey = listOfNotNull(
            project.findProperty("GOOGLE_MAPS_API_KEY")?.toString()?.takeIf { it.isNotBlank() },
            System.getenv("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() },
            readMapsKeyFromEnvFile()?.takeIf { it.isNotBlank() },
        ).firstOrNull() ?: ""

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

fun readMapsKeyFromEnvFile(): String? {
    val envFile = rootProject.file("../.env")
    if (!envFile.exists()) {
        return null
    }
    return envFile.readLines()
        .firstOrNull { it.startsWith("GOOGLE_MAPS_API_KEY=") }
        ?.substringAfter("=")
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
}
