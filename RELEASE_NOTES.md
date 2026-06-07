# Release Notes — v1.0.0 (2026-06-04)

CircleGuard v1.0.0 — release inicial completa: 8 microservicios sobre Kubernetes,
infraestructura como código multi-cloud (GCP + DigitalOcean), pipeline CI/CD en Jenkins,
observabilidad, seguridad y las 4 bonificaciones.

## Features

- feat: add gcp-provision.sh to bootstrap GKE cluster from .env
- feat: set GCP as primary cloud; update multicloud doc to cover rubric
- feat(prod): add promote-to-prod script (stage images → prod + k8s deploy)
- feat(observability+security): activate ELK stack and implement TLS with cert-manager
- feat(prod): complete prod overlay with imagePullPolicy and Prod Evidence stage
- feat: distributed tracing, E2E auth tests and operations manual
- feat: observability stack, RBAC and enhanced performance tests
- feat: design patterns, CI scripts and unit tests for design patterns

## Fixes

### Infraestructura / Kubernetes
- fix: set strategy Recreate on all infra deployments in stage/dev overlays
- fix: only restart infra pods stuck in Pending, not Running ones
- fix: reduce kafka memory request to 192Mi in dev and stage overlays
- fix: delete Pending infra pods and restart infra deployments on each deploy
- fix: apply reduce-resources patch to dev overlay (Insufficient memory)
- fix(k8s): revisionHistoryLimit=1 on all deployments to prevent 3x pod accumulation
- fix(k8s): apply neo4j/openldap scale-down patch to dev and master overlays
- fix(k8s): scale all namespaces to 0 on startup, register Windows scheduled task
- fix(deploy): auto scale-down neo4j/openldap and clean Error pods on every deploy
- fix(stage): scale down neo4j+openldap to 0 replicas to save RAM
- fix(k8s): reduce JVM heap and remove resource requests to avoid OOM on Docker Desktop
- fix(k8s): fix slow startup and probe timeouts for Spring services
- fix(k8s): fix stage overlay and infra issues

### Producción / despliegue
- fix(prod): prevent node OOM on 3x4GB cluster
- fix(prod): wait for stage pod termination before deploying prod + increase timeouts
- fix(prod): teardown stage before prod deploy + add scale-down-heavy-infra patch
- fix: scheduled teardown now covers prod (main branch) after Deploy Prod
- fix: copy kubeconfig to stable /tmp path before nohup teardown
- fix: revert teardown sleep unit back to minutes

### CI / Jenkins / herramientas
- fix: install docker-ce-cli and trivy from official apt repos in Jenkins image
- fix: install kubectl and trivy as binaries in Jenkins; always push images
- fix(infra): improve metrics-server installation with local manifest and RBAC
- fix(infra): add metrics-server installation for HPA autoscaling
- fix(infra): add memory limits to Jenkins container in docker-compose
- fix(pipeline): restore full-mode defaults and add service mesh (Istio)
- fix: pipeline runs full mode on webhook builds for dev/stage/main
- fix: corrección de 4 stages amarillos en pipeline CI
- fix(ci): clean before bootJar to avoid stale auth classes
- fix(ci): push images to deployed DockerHub namespace
- fix(ci): ensure gke auth plugin and gcloud kube auth
- fix(ci): harden k8s deploy context and startup readiness
- fix(jenkins): add extra_hosts to resolve kubernetes.docker.internal inside container

### Pruebas / Testcontainers
- fix: increase Gradle daemon heap to 768m to prevent OOM during compileKotlin
- fix: fork javac with 256m, drop clean, reduce daemon heap to 512m
- fix: workers.max=1 and test maxHeapSize=256m to prevent OOM on small droplet
- fix: gradle.properties mem limits + TC 1.20.4 + correct api.version property
- fix: upgrade Testcontainers to 1.20.4 with explicit deps to bypass Spring DM BOM
- fix: set DOCKER_API_VERSION=1.41 in test JVM via Gradle task
- fix(tests): mock CustomUserDetailsService to satisfy SecurityConfig in WebMvc tests
- fix(e2e): fix all 6 failing E2E tests
- fix(e2e): fix 401 on identity /map and 500 on promotion access-points
- fix(e2e): add Jackson for JSON serialization and disown port-forwards
- fix(e2e): pass explicit remote port 8080 to all port-forwards
- fix(e2e): fix port-forward PID loss in subshell and add stderr-only logging
- fix(e2e): kubectl wait stdout corrupts URL variable when called inside $()

### Seguridad / Auth / secretos
- fix: read jwt.secret and qr.secret from properties instead of QR_SECRET env var
- fix: JWT default secret >= 256 bits to pass WeakKeyException in tests
- fix(auth): read QR_SECRET directly in token services
- fix(auth): bind jwt.secret to QR_SECRET for startup
- fix(auth): define DaoAuthenticationProvider and password encoder beans
- fix(auth): make LDAP provider optional and fallback to local auth when LDAP unavailable
- fix(auth,gateway): add application.properties to bind QR_SECRET env var to qr.secret property
- fix(k8s): create qr-secret as static resource instead of secretGenerator to prevent name hashing
- fix(k8s): inject QR_SECRET into auth and gateway deployments
- fix(identity): expose health endpoint correctly for k8s probes
- fix(identity): allow unauthenticated /actuator/health for k8s probes

### Observabilidad / smoke / scans
- fix: NetworkPolicy bloquea egreso de smoke-curl, locust y zap
- fix: smoke-curl sleep 1800s, zap como pod in-cluster sin port-forward
- fix: zap imagen nueva ghcr.io, trivy cache volumen, redis health deshabilitado
- fix: trivy escanea solo tag de entorno, locust K8s-only, metrics sin CSV no falla
- fix: kubectl version sin --short (eliminado en kubectl 1.28+)
- fix: kafka OOM crash y health indicators de infra en servicios app
- fix: force pod restart on deploy y evidence sin fallar en deployments escalados a 0

### Flyway / base de datos
- fix(flyway): per-service history table to prevent V1 conflicts on shared DB
- fix(flyway): use per-service history table with baseline-on-migrate=true
- fix(flyway): revert to simple config, keep only @EnableWebSecurity fix
- fix(k8s): disable Flyway validation on migrate for stage

### Terraform
- fix(terraform): reference existing qr-secret via data source to avoid conflicts with kustomize secretGenerator
- fix(terraform): update outputs to reference data source for namespaces
- fix(terraform): use data source for namespaces to avoid conflicts when already exist
- fix(k8s): provide vault secrets for identity service

## Docs
- docs: add namespace management and resource teardown instructions

## Performance
- perf(ci): reduce pipeline duration by ~15-20 min

## CI
- ci: speed up pipeline by building bootJar for services and skipping tests during quick iterations
- ci: prevent Jenkins prompt for TEARDOWN, default to false via env var
- ci: make teardown a manual input step (remove pipeline parameter)
- ci(smoke): wait deployments, retry HTTP checks, and print diagnostics on failure
- ci(docker): add missing Dockerfiles for form and notification services
- ci(docker): use authenticated DockerHub namespace for image pushes
- ci(jenkins): inject GCP SA file and expose GKE vars to terraform stage
- ci(terraform): auto-configure GCP creds and enable use_gke via env; mount SA into terraform container

## Chore
- chore: add k8s-startup-cleanup.ps1 to run after Docker Desktop restart
