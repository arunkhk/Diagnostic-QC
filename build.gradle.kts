// Root project build file
// This project contains both Android native modules and Flutter module

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
    delete("${rootProject.projectDir}/android/build")
    delete("${rootProject.projectDir}/android/app/build")
    delete("${rootProject.projectDir}/flutter_module/build")
}