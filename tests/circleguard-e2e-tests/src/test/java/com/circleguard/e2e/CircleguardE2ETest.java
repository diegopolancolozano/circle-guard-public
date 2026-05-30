package com.circleguard.e2e;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.*;
import java.io.File;

import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class CircleguardE2ETest {

    private String authBaseUrl;
    private String identityBaseUrl;
    private String promotionBaseUrl;
    private String gatewayBaseUrl;
    private String fileBaseUrl;

    @BeforeAll
    void setUp() {
        authBaseUrl = requiredEnv("AUTH_BASE_URL");
        identityBaseUrl = requiredEnv("IDENTITY_BASE_URL");
        promotionBaseUrl = requiredEnv("PROMOTION_BASE_URL");
        gatewayBaseUrl = requiredEnv("GATEWAY_BASE_URL");
        fileBaseUrl = requiredEnv("FILE_BASE_URL");

        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
    }

    // ── Auth service ──────────────────────────────────────────────────────────

    @Test
    void authServiceHealthShouldBeUp() {
        given()
                .baseUri(authBaseUrl)
        .when()
                .get("/actuator/health")
        .then()
                .statusCode(200)
                .body("status", equalTo("UP"));
    }

    @Test
    void shouldRejectLoginWithInvalidCredentials() {
        given()
                .baseUri(authBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of("username", "no-such-user-e2e", "password", "wrong"))
        .when()
                .post("/api/v1/auth/login")
        .then()
                .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(400)));
    }

    @Test
    void shouldLoginAndReceiveJwtToken() {
        String user = System.getenv("LOAD_TEST_USER");
        String pass = System.getenv("LOAD_TEST_PASS");
        Assumptions.assumeTrue(user != null && !user.isBlank() && pass != null && !pass.isBlank(),
                "LOAD_TEST_USER / LOAD_TEST_PASS not set — skipping login happy-path test");

        given()
                .baseUri(authBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of("username", user, "password", pass))
        .when()
                .post("/api/v1/auth/login")
        .then()
                .statusCode(200)
                .body("token", notNullValue())
                .body("type", equalTo("Bearer"))
                .body("anonymousId", matchesPattern("^[0-9a-fA-F-]{36}$"));
    }

    // ── Identity service ──────────────────────────────────────────────────────

    @Test
    void shouldMapIdentityToAnonymousId() {
        String realIdentity = "e2e-" + UUID.randomUUID() + "@circleguard.edu";

        given()
                .baseUri(identityBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of("realIdentity", realIdentity))
        .when()
                .post("/api/v1/identities/map")
        .then()
                .statusCode(200)
                .body("anonymousId", notNullValue())
                .body("anonymousId", matchesPattern("^[0-9a-fA-F-]{36}$"));
    }

    @Test
    void shouldRejectInvalidGatewayToken() {
        given()
                .baseUri(gatewayBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of("token", "invalid-token"))
        .when()
                .post("/api/v1/gate/validate")
        .then()
                .statusCode(200)
                .body("valid", equalTo(false))
                .body("status", equalTo("RED"))
                .body("message", containsString("Invalid"));
    }

    @Test
    void shouldRegisterPromotionHandshake() {
        given()
                .baseUri(promotionBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of(
                        "macAddress", "AA:BB:CC:DD:EE:" + UUID.randomUUID().toString().substring(0, 2),
                        "anonymousId", UUID.randomUUID().toString()
                ))
        .when()
                .post("/api/v1/sessions/handshake")
        .then()
                .statusCode(200);
    }

    @Test
    void shouldUploadFile() {
        File tempFile;
        try {
            tempFile = File.createTempFile("e2e-upload", ".txt");
            java.nio.file.Files.writeString(tempFile.toPath(), "e2e-content");
        } catch (java.io.IOException e) {
            throw new RuntimeException(e);
        }

        try {
            given()
                    .baseUri(fileBaseUrl)
                    .multiPart("file", tempFile, "text/plain")
            .when()
                    .post("/api/v1/files/upload")
            .then()
                    .statusCode(200)
                    .body("filename", notNullValue());
        } finally {
            tempFile.delete();
        }
    }

    @Test
    void shouldReturnNotFoundForUnknownAccessPoint() {
        given()
                .baseUri(promotionBaseUrl)
        .when()
                .get("/api/v1/access-points/{id}", UUID.randomUUID())
        .then()
                .statusCode(404);
    }

    @Test
    void shouldRejectEmptyGatewayToken() {
        given()
                .baseUri(gatewayBaseUrl)
                .contentType(ContentType.JSON)
                .body(Map.of("token", ""))
        .when()
                .post("/api/v1/gate/validate")
        .then()
                .statusCode(200)
                .body("valid", equalTo(false));
    }

    private static String requiredEnv(String key) {
        // Check System properties first (from -D gradle args), then fall back to environment variables
        String value = System.getProperty(key);
        if (value == null || value.isBlank()) {
            value = System.getenv(key);
        }
        Assumptions.assumeTrue(value != null && !value.isBlank(), () -> key + " no está definido");
        return value.replaceAll("/+$", "");
    }
}