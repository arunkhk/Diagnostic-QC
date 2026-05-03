# Android Host App

This is the Android host application that embeds the Flutter module.

## Structure

- `app/` - Main Android application module
  - `src/main/AndroidManifest.xml` - Contains all Android permissions
  - `src/main/java/com/example/qc/MainActivity.kt` - Main activity that hosts Flutter

## Adding Native Android Modules

1. Create your module in `android/modules/your-module-name/`
2. Add to `android/settings.gradle.kts`:
   ```kotlin
   include(":modules:your-module-name")
   ```
3. Add dependency in `android/app/build.gradle.kts`:
   ```kotlin
   dependencies {
       implementation(project(":modules:your-module-name"))
   }
   ```

## Building

```bash
cd android
./gradlew assembleDebug
```

## Permissions

All Android permissions are declared in `app/src/main/AndroidManifest.xml`. When adding new permissions required by Flutter plugins or native modules, add them there.

