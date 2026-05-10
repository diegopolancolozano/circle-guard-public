dependencies {
    compileOnly("org.projectlombok:lombok:1.18.32")
    annotationProcessor("org.projectlombok:lombok:1.18.32")
    testCompileOnly("org.projectlombok:lombok:1.18.32")
    testAnnotationProcessor("org.projectlombok:lombok:1.18.32")
    testImplementation("io.rest-assured:rest-assured:5.4.0")
    testImplementation("io.rest-assured:json-path:5.4.0")
    // Required by REST Assured to serialize Map bodies as JSON
    testImplementation("com.fasterxml.jackson.core:jackson-databind:2.17.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
}

tasks.withType<Test> {
    // Forward URL system properties from Gradle JVM to test JVM
    listOf(
        "IDENTITY_BASE_URL",
        "PROMOTION_BASE_URL",
        "GATEWAY_BASE_URL",
        "FILE_BASE_URL"
    ).forEach { key ->
        val value = System.getProperty(key) ?: System.getenv(key)
        if (!value.isNullOrBlank()) {
            systemProperty(key, value)
        }
    }
}
