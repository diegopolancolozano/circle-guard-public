# Locust Performance Tests

This folder contains the Locust workload used by the Jenkins pipeline.

- The workload targets identity mapping and gateway validation flows.
- Endpoints are injected via environment variables.

Required environment variables:
- IDENTITY_BASE_URL
- GATEWAY_BASE_URL
