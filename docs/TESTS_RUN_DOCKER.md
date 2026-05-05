Running tests inside Docker (VM) - quick guide

This will start dependent services (Postgres, Neo4j, Redis, Kafka, OpenLDAP)
and then run `./gradlew test` inside a container that has access to the repository.

Notes:
- We mount the host Docker socket into the test runner so Testcontainers can launch sibling containers.
- Running tests inside Docker isolates your host and matches CI behavior.

Commands (run on the VM where the repo is checked out):

# 0) Enter the VM (if Docker runs on a remote Linux host)
ssh <user>@<vm-ip>

# 0.1) Move to project folder in that VM
cd /path/to/circle-guard-public

# Start infra + run tests (will exit when tests finish)
docker compose -f docker-compose.test.yml up --abort-on-container-exit --remove-orphans --build

# Inspect test-runner exit code (0 = success)
docker compose -f docker-compose.test.yml ps

docker compose -f docker-compose.test.yml down

# If you want to run tests for a single module, open a shell in the test-runner and run gradle there:
# Start compose in background
docker compose -f docker-compose.test.yml up -d postgres neo4j redis kafka

# Start test runner shell
docker run --rm -it -v "$(pwd)":/workspace -w /workspace -v /var/run/docker.sock:/var/run/docker.sock eclipse-temurin:21-jdk /bin/sh
# inside container
chmod +x ./gradlew
./gradlew :services:circleguard-auth-service:test --no-daemon

# If test-runner is already up in compose, enter directly into that container:
docker compose -f docker-compose.test.yml exec test-runner /bin/sh

Troubleshooting:
- If Testcontainers cannot start, check that `/var/run/docker.sock` is correctly mounted and the Docker user inside the container has permissions.
- If some integration tests still try to use external DB URLs, ensure test profiles use H2 or the test resources are configured to use Testcontainers.

