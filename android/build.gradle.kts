allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some plugins (file_picker 8.x) still compile against Android 34, while the
// AndroidX and Flutter plugin libraries they pull in now require 36, which
// fails AAR metadata checks. Compile every Android library module against
// SDK 36. compileSdk only decides which APIs are visible at build time; minSdk
// and targetSdk are untouched, so device support and runtime behaviour do not
// change.
//
// It must run after each plugin's own build script (which sets its
// compileSdk), and Gradle 9 throws if afterEvaluate is registered on a project
// that is already evaluated — hence the state check.
subprojects {
    val forceCompileSdk: Project.() -> Unit = {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.compileSdk = 36
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
