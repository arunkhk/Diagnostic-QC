pluginManagement {
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        var path = properties.getProperty("flutter.sdk")
            ?: throw Exception("flutter.sdk not set in local.properties")
        path = path.trim().trimEnd('/')
        // IDE/tools sometimes set flutter.sdk to the flutter executable path (.../bin/flutter)
        val composite = java.io.File(path, "packages/flutter_tools/gradle")
        if (!composite.isDirectory) {
            val mistaken = java.io.File(path)
            if (mistaken.name == "flutter" && mistaken.parentFile?.name == "bin") {
                path = mistaken.parentFile!!.parentFile!!.canonicalPath
            }
        }
        val resolved = java.io.File(path, "packages/flutter_tools/gradle")
        require(resolved.isDirectory) {
            "Flutter SDK '$path' has no packages/flutter_tools/gradle. " +
                "Set flutter.sdk in local.properties to the Flutter SDK root (folder containing bin/ and packages/)."
        }
        path
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

