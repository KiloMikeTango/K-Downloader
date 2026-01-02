buildscript {
    repositories {
        google()
        mavenCentral()  
    }
}

configurations.all {
    resolutionStrategy {
        // Force Gradle to use version 6.0 instead of the missing 6.0-2
        force("com.arthenica:ffmpeg-kit-https:6.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
