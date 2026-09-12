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
subprojects {
    project.evaluationDependsOn(":app")
}

// Force all Android library subprojects (e.g. file_picker) to use compileSdk 36
// so they satisfy flutter_plugin_android_lifecycle's requirement.
// gradle.afterProject fires AFTER each project's build script is evaluated,
// ensuring we overwrite any compileSdk = 34 set by the plugin itself.
gradle.afterProject {
    extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        ?.let { lib -> lib.compileSdk = 36 }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
