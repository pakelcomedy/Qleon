// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google() // Google's Maven repository for Android tools and libraries
        mavenCentral() // Central Maven repository for other dependencies
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}
