plugins {
    id("org.springframework.boot") version "3.2.4" apply false
    id("io.spring.dependency-management") version "1.1.4" apply false
    kotlin("jvm") version "1.9.24" apply false
    kotlin("plugin.spring") version "1.9.24" apply false
    kotlin("plugin.jpa") version "1.9.24" apply false
    id("org.sonarqube") version "5.0.0.4638"
}

allprojects {
    group = "com.circleguard"
    version = "1.0.0-SNAPSHOT"

    repositories {
        mavenCentral()
    }
}

sonarqube {
    properties {
        property("sonar.projectKey", System.getenv("SONAR_PROJECT_KEY") ?: "circleguard")
        property("sonar.projectName", System.getenv("SONAR_PROJECT_NAME") ?: "CircleGuard")
    }
}

subprojects {
    // Spring Boot 3.2.4 arrastra Testcontainers 1.19.7 que usa docker-java con API 1.32.
    // Docker 29.x exige API mínima 1.40 → forzar 1.20.4 que soporta Docker 29.x.
    // NO forzamos docker-java por separado: dejar que TC 1.20.4 gestione su propia versión.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.testcontainers") {
                useVersion("1.20.4")
            }
        }
    }

    apply(plugin = "java")
    apply(plugin = "org.jetbrains.kotlin.jvm")
    apply(plugin = "jacoco")
    extensions.configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
    }

    dependencies {
        "implementation"(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
        "testImplementation"(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
        "implementation"("io.micrometer:micrometer-registry-prometheus")
        "implementation"("io.micrometer:micrometer-tracing-bridge-otel")
        "implementation"("io.opentelemetry:opentelemetry-exporter-otlp")
        "compileOnly"("org.projectlombok:lombok")
        "annotationProcessor"("org.projectlombok:lombok")
        "testCompileOnly"("org.projectlombok:lombok")
        "testAnnotationProcessor"("org.projectlombok:lombok")
        "implementation"("org.jetbrains.kotlin:kotlin-reflect")
        "testImplementation"("org.springframework.boot:spring-boot-starter-test")
        "testRuntimeOnly"("com.h2database:h2")
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions {
            freeCompilerArgs = listOf("-Xjsr305=strict")
            jvmTarget = "21"
        }
    }

    tasks.withType<Test> {
        // Docker 29.x exige API >= 1.40; docker-java defaultea a 1.32.
        // Setear como env var Y system property para que el JVM forkeado
        // lo reciba sin importar el Gradle daemon ni el entorno Jenkins.
        environment("DOCKER_API_VERSION", "1.41")
        systemProperty("DOCKER_API_VERSION", "1.41")
        useJUnitPlatform()
        finalizedBy("jacocoTestReport")
    }

    extensions.configure<org.gradle.testing.jacoco.plugins.JacocoPluginExtension> {
        toolVersion = "0.8.11"
    }

    tasks.withType<org.gradle.testing.jacoco.tasks.JacocoReport> {
        reports {
            xml.required.set(true)
            html.required.set(true)
            csv.required.set(false)
        }
    }
}
