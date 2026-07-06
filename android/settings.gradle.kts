pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
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
    id("com.android.application") version "8.7.0" apply false
    // share_plus >=12 ships Kotlin 2.x plugin code; the Flutter 3.29 template
    // pins Kotlin 1.8.22, which cannot read it and fails compileReleaseKotlin.
    // Pin to 2.1.20 here so no post-generate sed is needed in CI.
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
}

include(":app")
