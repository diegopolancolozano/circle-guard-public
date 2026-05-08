# 🚀 Jenkins Local - Guía Detallada

Este documento explica cómo ejecutar Jenkins localmente en Docker y configurarlo para desplegar a GCP.

## ⚡ Inicio Rápido (30 segundos)

```bash
# Asegúrate que estás logged en Docker
docker login

# Copiar kubeconfig de GCP (opcional si no se monta)
mkdir -p ~/.kube
cp /ruta/a/kubeconfig ~/.kube/config

# Ejecutar Jenkins
docker compose -f docker-compose.jenkins.yml up -d

# Esperar ~2 minutos y acceder a http://localhost:8080
# Obtener contraseña:
docker compose -f docker-compose.jenkins.yml logs jenkins | grep initialAdminPassword
```

## 🔧 Configuración Inicial en Jenkins UI

1. **Desbloquear Jenkins**
   - Copiar la contraseña inicial del comando anterior
   - Pegar en la página de desbloqueo

2. **Instalar Plugins Sugeridos** (opcional)
   - Los plugins principales ya vienen preinstalados
   - Puedes saltarte o dejar que Jenkins instale sugerencias

3. **Crear Usuario Admin**
   - Username: admin
   - Password: (elige algo seguro)

4. **Configurar URL de Jenkins**
   - Jenkins URL: http://localhost:8080/

## � Agregar Credenciales

En Jenkins UI → **Manage Jenkins** → **Credentials** → **System** → **Global credentials**:

### 1. Docker Hub
- **Type**: Username with password
- **Username**: tu-usuario-dockerhub
- **Password**: tu-token-dockerhub
- **ID**: `dockerhub-credentials`

### 2. Kubeconfig (GCP Cluster Access)
- **Type**: Secret file
- **File**: ~/.kube/config
- **ID**: `kubeconfig-credentials`

### 3. GCP Service Account
- **Type**: Secret file
- **File**: /ruta/a/gcp-sa.json
- **ID**: `gcp-sa-json`

### 4. QR Secret (Tokens JWT/QR)
- **Type**: Secret text
- **Secret**: change-me-change-me-change-me-change-me (o tu valor actual)
- **ID**: `qr-secret-value`

## 📦 Crear Multibranch Pipeline Job

Jenkins UI → **New Item** → **Multibranch Pipeline**

1. **Name**: circleguard

2. **Branch Sources**
   - Add source → **Git**
   - Project Repository: https://github.com/tu-usuario/circle-guard-public.git

3. **Build Configuration**
   - Mode: by Jenkinsfile
   - Script Path: `Jenkinsfile`

4. **Guardar** y Jenkins escanea el repo automáticamente

5. Cada push a `dev`, `stage` o `main` dispara un build

## 🚀 Primeros Pasos en Builds

```bash
# Verificar que Jenkins puede usar Docker
docker compose -f docker-compose.jenkins.yml exec jenkins docker ps

# Verificar que Jenkins puede acceder a Kubernetes
docker compose -f docker-compose.jenkins.yml exec jenkins kubectl cluster-info

# Ver logs de Jenkins
docker compose -f docker-compose.jenkins.yml logs -f jenkins

# Hacer push a rama stage para disparar primer build
git checkout stage
git push origin stage
```

Jenkins automáticamente detecta el push y ejecuta el pipeline.

## ⛔ Detener Jenkins

```bash
docker-compose -f docker-compose.jenkins.yml down
```

## 💾 Persistencia

- Todos los datos de Jenkins se guardan en volumen Docker `jenkins-data`
- Los trabajos, credenciales y configuración persisten entre reinicios
- Para limpiar todo: `docker volume rm jenkins-data`

## ⛔ Troubleshooting

### Jenkins no arranca
```bash
docker compose -f docker-compose.jenkins.yml logs jenkins
```

### No puede hacer login a Docker Hub
```bash
docker compose -f docker-compose.jenkins.yml exec jenkins docker login
```

### Kubeconfig no se carga
```bash
# Verificar permisos
docker compose -f docker-compose.jenkins.yml exec jenkins ls -la ~/.kube/

# Verificar conexión
docker compose -f docker-compose.jenkins.yml exec jenkins kubectl cluster-info
```

### Build falla por permisos de Docker
```bash
# Reiniciar jenkins user
docker compose -f docker-compose.jenkins.yml exec -u root jenkins chown jenkins:jenkins /var/run/docker.sock
```

### Limpiar volúmenes y reiniciar
```bash
docker compose -f docker-compose.jenkins.yml down -v
docker volume rm circle-guard-public_jenkins-data
docker compose -f docker-compose.jenkins.yml up -d
```

## 📋 Pipeline Existente

El [Jenkinsfile](./Jenkinsfile) está completamente listo y contiene:

✅ **Stages**:
- Checkout (obtener código)
- Build (compilar 6 microservicios)
- Build & Push Images (Docker Hub)
- Terraform Bootstrap (crear recursos en GCP)
- Deploy dev/stage/prod (a namespaces)
- Smoke Tests (verificar 4 servicios críticos)
- Evidence (guardar logs)

✅ **Ramas automáticas**:
- `dev` → deploya a namespace `dev`
- `stage` → deploya a namespace `stage`
- `main` → deploya a namespace `prod`

**No se necesitan cambios en el Jenkinsfile.**

## 🌐 Despliegue en GCP

Aunque Jenkins corre localmente, sigue desplegando a:
- **GCP Project**: `proyectoIngesoft`
- **Cluster**: `circle-guard-cluster` (us-central1)
- **Namespaces**: dev, stage, prod
- **Registry**: Docker Hub (`diegoapolancol/circleguard-*`)

## 🎯 Resumen

**El flujo es simple:**

1. `docker compose -f docker-compose.jenkins.yml up -d` → Jenkins levanta en 2 min
2. http://localhost:8080 → Desbloquear, crear usuario, agregar credenciales
3. Crear Multibranch Pipeline job apuntando a GitHub
4. Push a rama `stage` → Jenkins dispara build automáticamente
5. 5-10 min después: 6 microservicios desplegados en GCP (namespace stage)

**La diferencia con VM en GCP**: Ahora Jenkins corre localmente en tu máquina, pero todos los despliegues siguen siendo a GCP proyectoIngesoft.

---

**Nota**: Si quieres usar Docker-in-Docker, agrega el profile:
```bash
docker-compose -f docker-compose.jenkins.yml --profile optional up -d
```

Pero usualmente montar `/var/run/docker.sock` es suficiente.
