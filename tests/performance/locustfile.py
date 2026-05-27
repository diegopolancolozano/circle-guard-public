import os
import uuid
import json
from locust import HttpUser, task, between, events
from locust.runners import MasterRunner

AUTH_BASE_URL      = os.getenv("AUTH_BASE_URL",      "http://localhost:18086")
IDENTITY_BASE_URL  = os.getenv("IDENTITY_BASE_URL",  "http://localhost:18087")
GATEWAY_BASE_URL   = os.getenv("GATEWAY_BASE_URL",   "http://localhost:18083")
PROMOTION_BASE_URL = os.getenv("PROMOTION_BASE_URL", "http://localhost:18088")

# Credentials for the auth endpoint (seeded in dev/stage via LDAP or local DB)
TEST_USERNAME = os.getenv("LOAD_TEST_USER", "testuser")
TEST_PASSWORD = os.getenv("LOAD_TEST_PASS", "password")


class GatewayUser(HttpUser):
    """
    Simulates external validation requests hitting the gateway — the highest-traffic path.
    """
    host = GATEWAY_BASE_URL
    wait_time = between(0.5, 2)

    @task(7)
    def validate_invalid_token(self):
        self.client.post(
            "/api/v1/gate/validate",
            json={"token": "invalid-token"},
            name="gateway/validate [invalid]",
        )

    @task(1)
    def validate_empty_token(self):
        self.client.post(
            "/api/v1/gate/validate",
            json={"token": ""},
            name="gateway/validate [empty]",
        )

    @task(2)
    def health_check(self):
        self.client.get(
            "/actuator/health",
            name="gateway/health",
        )


class AuthUser(HttpUser):
    """
    Simulates authenticated user flows: login + identity resolution.
    """
    host = AUTH_BASE_URL
    wait_time = between(1, 4)

    def on_start(self):
        self.token = None
        self._login()

    def _login(self):
        with self.client.post(
            "/api/v1/auth/login",
            json={"username": TEST_USERNAME, "password": TEST_PASSWORD},
            name="auth/login",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                data = resp.json()
                self.token = data.get("token")
                resp.success()
            else:
                resp.failure(f"Login failed: {resp.status_code}")

    @task(3)
    def login_flow(self):
        self._login()

    @task(1)
    def auth_health(self):
        self.client.get("/actuator/health", name="auth/health")


class IdentityUser(HttpUser):
    """
    Simulates identity-service anonymisation requests.
    """
    host = IDENTITY_BASE_URL
    wait_time = between(1, 3)

    @task(5)
    def map_identity(self):
        real_id = f"load-{uuid.uuid4()}@circleguard.edu"
        self.client.post(
            "/api/v1/identities/map",
            json={"realIdentity": real_id},
            name="identity/map",
        )

    @task(1)
    def identity_health(self):
        self.client.get("/actuator/health", name="identity/health")


class PromotionUser(HttpUser):
    """
    Simulates promotion-service handshake traffic.
    """
    host = PROMOTION_BASE_URL
    wait_time = between(2, 5)

    @task(3)
    def handshake(self):
        self.client.post(
            "/api/v1/sessions/handshake",
            json={
                "sourceId": str(uuid.uuid4()),
                "targetId": str(uuid.uuid4()),
            },
            name="promotion/handshake",
        )

    @task(1)
    def promotion_health(self):
        self.client.get("/actuator/health", name="promotion/health")
