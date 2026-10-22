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
    project.plugins.withId("com.android.library") {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val ns = when (project.name) {
                    "telephony" -> "com.shounakmulay.telephony"
                    else -> null
                }
                if (ns != null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, ns)
                }
            } catch (_: Exception) {}
        }
    }

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    for (m in android.javaClass.methods) {
                        if (m.name == "compileSdkVersion" && m.parameterCount == 1 && m.parameterTypes[0] == java.lang.Integer.TYPE) {
                            m.invoke(android, 35)
                        } else if (m.name == "setCompileSdkVersion" && m.parameterCount == 1) {
                            m.invoke(android, 35)
                        } else if (m.name == "setCompileSdk" && m.parameterCount == 1) {
                            m.invoke(android, 35)
                        }
                    }
                } catch (_: Exception) {}

                try {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", Object::class.java)
                    val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", Object::class.java)
                    setSource.invoke(compileOptions, JavaVersion.VERSION_11)
                    setTarget.invoke(compileOptions, JavaVersion.VERSION_11)
                } catch (_: Exception) {}

                try {
                    val kotlinOptions = android.javaClass.getMethod("getKotlinOptions").invoke(android)
                    val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                    setJvmTarget.invoke(kotlinOptions, "11")
                } catch (_: Exception) {}
            }
        }

        tasks.matching { it.name.contains("AarMetadata") }.configureEach {
            enabled = false
        }

        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }

        tasks.matching { it.name.contains("compile") && it.name.contains("Kotlin") }.configureEach {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "11")
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
