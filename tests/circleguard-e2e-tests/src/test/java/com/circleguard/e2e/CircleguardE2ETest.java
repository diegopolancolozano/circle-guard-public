package com.circleguard.e2e;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.*;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class CircleguardE2ETest {

    private String identityBaseUrl;
    private String promotionBaseUrl;
    private String gatewayBaseUrl;
    private String fileBaseUrl;
    private String dashboardBaseUrl;

    @BeforeAll
    void setUp() {
        identityBaseUrl = requiredEnv("IDENTITY_BASE_URL");
        promotionBaseUrl = requiredEnv("PROMOTION_BASE_URL");
        gatewayBaseUrl = requiredEnv("GATEWAY_BASE_URL");
        fileBaseUrl = requiredEnv("FILE_BASE_URL");
        dashboardBaseUrl = requiredEnv("DASHBOARD_BASE_URL");

        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
    }

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
    void shouldUploadFile() throws Exception {
        Path tempDir = Files.createTempDirectory("circleguard-e2e-");
        Path tempFile = tempDir.resolve("circleguard-e2e.txt");
        Files.writeString(tempFile, "circle-guard-e2e", StandardCharsets.UTF_8);

        given()
                .baseUri(fileBaseUrl)
                .multiPart("file", tempFile.toFile())
        .when()
                .post("/api/v1/files/upload")
        .then()
                .statusCode(200)
                .body("filename", endsWith("_circleguard-e2e.txt"));
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
    void shouldExposeDashboardHealthBoard() {
        given()
                .baseUri(dashboardBaseUrl)
                .accept(ContentType.JSON)
        .when()
                .get("/api/v1/analytics/health-board")
        .then()
                .statusCode(200)
                .body("timestamp", notNullValue());
    }

    private static String requiredEnv(String key) {
        String value = System.getenv(key);
        Assumptions.assumeTrue(value != null && !value.isBlank(), () -> key + " no está definido");
        return value.replaceAll("/+$", "");
    }
}