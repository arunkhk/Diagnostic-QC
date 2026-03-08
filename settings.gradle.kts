pluginManagement {
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
            ?: throw Exception("flutter.sdk not set in local.properties")
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
}

rootProject.name = "QC"
// Include Android app module
include(":android:app")
project(":android:app").projectDir = file("android/app")

// Include Flutter module
include(":flutter_module")
project(":flutter_module").projectDir = file("flutter_module")

