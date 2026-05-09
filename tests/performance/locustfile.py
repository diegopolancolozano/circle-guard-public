import os
import uuid
from locust import HttpUser, task, between

IDENTITY_BASE_URL = os.getenv("IDENTITY_BASE_URL", "")
GATEWAY_BASE_URL = os.getenv("GATEWAY_BASE_URL", "")


class CircleGuardUser(HttpUser):
    wait_time = between(1, 3)

    @task(5)
    def validate_gate(self):
        if not GATEWAY_BASE_URL:
            return
        payload = {"token": "invalid"}
        self.client.post(f"{GATEWAY_BASE_URL}/api/v1/gate/validate", json=payload, name="gateway_validate")

    # @task(2)
    # def map_identity(self):
    #     # TODO: Implement identity map with proper auth headers
    #     # This endpoint requires authentication that needs to be implemented
    #     if not IDENTITY_BASE_URL:
    #         return
    #     payload = {"realIdentity": f"load-{uuid.uuid4()}@circleguard.edu"}
    #     self.client.post(f"{IDENTITY_BASE_URL}/api/v1/identities/map", json=payload, name="identity_map")
