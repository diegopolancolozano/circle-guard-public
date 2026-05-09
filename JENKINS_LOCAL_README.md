# 🐳 Jenkins Local - Circle Guard CI/CD

Configuración completa de Jenkins ejecutándose localmente en Docker, desplegando a **GCP (proyectoIngesoft)**.

## ⚡ Inicio Rápido (2 comandos)

### 1️⃣ Preparar Credenciales

```bash
# Asegurar que estás logged en Docker Hub
docker login

# Copiar kubeconfig de GCP a ~/.kube/config
mkdir -p ~/.kube
# (Copiar tu kubeconfig aquí)
```

### 2️⃣ Iniciar Jenkins

```bash
docker compose -f docker-compose.jenkins.yml up -d
```

**Esperar ~2 minutos** y acceder a **http://localhost:8080**

Obtener contraseña inicial:
```bash
docker compose -f docker-compose.jenkins.yml logs jenkins | grep initialAdminPassword
```

## 📋 Archivos Principales

| Archivo | Propósito |
|---------|-----------|
| `docker-compose.jenkins.yml` | Configuración Docker Compose (Jenkins + volúmenes + credenciales) |
| `Dockerfile.jenkins` | Imagen personalizada con 19 plugins + docker/kubectl/git |
| `jenkins-init/plugins.txt` | Lista de plugins (Pipeline, Git, Docker, K8s, etc.) |
| `jenkins-init/01-install-plugins.groovy` | Auto-instalación de plugins al arrancar |
| `.env.jenkins.example` | Variables de entorno (GCP, Docker, K8s) |

## 🔧 Configuración en Jenkins UI

Después de acceder a Jenkins (http://localhost:8080):

### 1. Desbloquear Jenkins
- Copiar contraseña inicial del terminal
- Pegar en la página de desbloqueo
- Crear usuario admin

### 2. Instalar Plugins
- Seleccionar "Install suggested plugins"
- Esperar a que se instalen los necesarios

### 3. Agregar Credenciales (Manage Jenkins → Credentials)

#### Docker Hub
- **ID**: `dockerhub-credentials`
- **Tipo**: Username with password
- **Usuario**: tu-usuario-dockerhub
- **Password**: token-dockerhub

#### Kubeconfig (GCP Cluster)
- **ID**: `kubeconfig-credentials`
- **Tipo**: Secret file
- **Archivo**: ~/.kube/config

#### GCP Service Account
- **ID**: `gcp-sa-json`
- **Tipo**: Secret file
- **Archivo**: ruta/al/gcp-sa.json

#### QR Secret
- **ID**: `qr-secret-value`
- **Tipo**: Secret text
- **Valor**: `change-me-change-me-change-me-change-me` (o el actual)

### 4. Crear Multibranch Pipeline

**Nueva Tarea → Multibranch Pipeline**
- **Name**: `circleguard`
- **Branch Sources**:
  - Agregar **Git**
  - URL: `https://github.com/tu-usuario/circle-guard-public.git`
- **Build Configuration**: Script Path = `Jenkinsfile`
- **Guardar** y escanear

## 🚀 Primeros Pasos

```bash
# Ver status
docker compose -f docker-compose.jenkins.yml ps

# Ver logs (última línea muestra contraseña)
docker compose -f docker-compose.jenkins.yml logs jenkins | tail -20

# Detener
docker compose -f docker-compose.jenkins.yml down

# Reiniciar
docker compose -f docker-compose.jenkins.yml restart jenkins

# Ver logs en tiempo real
docker compose -f docker-compose.jenkins.yml logs -f jenkins
```

## 📊 Pipeline Existente

El [Jenkinsfile](./Jenkinsfile) ya está configurado para:

✅ **Checkout** → Obtener código  
✅ **Build** → Compilar 6 microservicios  
✅ **Build & Push Images** → Crear imágenes Docker (pre-build optimizado)  
✅ **Terraform Bootstrap** → Crear recursos en GCP  
✅ **Deploy Dev/Stage/Prod** → Desplegar a namespaces  
✅ **Smoke Tests** → Verificar 4 servicios críticos  
✅ **Evidence** → Guardar logs  

**Ramas automáticas**:
- `dev` → Despliega a `dev` namespace
- `stage` → Despliega a `stage` namespace  
- `main` → Despliega a `prod` namespace

## 🎯 Ejemplo: Deploy a Stage

1. **Hacer push a rama stage**:
   ```bash
   git checkout stage
   git pull origin stage
   git push origin stage
   ```

2. **Jenkins detecta cambio** y dispara build automáticamente (o manual desde UI)

3. **Pipeline ejecuta**:
   - Compila 6 jars
   - Construye 6 imágenes Docker
   - Push a Docker Hub con tag `:stage`
   - Aplica Terraform en GCP
   - Despliega a namespace `stage` en circle-guard-cluster
   - Ejecuta smoke tests

4. **Verificar en GCP**:
   ```bash
   kubectl -n stage get pods
   kubectl -n stage get svc
   kubectl -n stage logs deployment/circleguard-auth-service
   ```

## 💾 Datos Persistentes

- **Volumen**: `jenkins-data` (persiste entre reinicios)
- **Almacena**: Trabajos, credenciales, logs, plugins
- **Para limpiar**: `docker volume rm jenkins-data` (⚠️ destructivo)

## 🛑 Comando de Utilidad

```bash
# Construir imagen (si hay cambios en plugins)
./jenkins-local.sh build

# Detener Jenkins
./jenkins-local.sh stop

# Reiniciar Jenkins
./jenkins-local.sh restart

# Limpiar TODOS los datos
./jenkins-local.sh clean

# Ejecutar comando dentro del contenedor
./jenkins-local.sh exec kubectl get pods -n stage

# Hacer docker login desde Jenkins
./jenkins-local.sh docker-login
```

## ⚠️ Troubleshooting

### Jenkins no arranca
```bash
# Ver logs detallados
docker compose -f docker-compose.jenkins.yml logs jenkins
```

### Obtener contraseña inicial
```bash
docker compose -f docker-compose.jenkins.yml logs jenkins | grep initialAdminPassword
```

### Reiniciar Jenkins
```bash
docker compose -f docker-compose.jenkins.yml restart jenkins
```

### Limpiar TODO (⚠️ destructivo)
```bash
docker compose -f docker-compose.jenkins.yml down -v
docker volume rm circle-guard-public_jenkins-data
```

## 📝 Próximos Pasos

1. ✅ Ejecutar `docker compose -f docker-compose.jenkins.yml up -d`
2. ✅ Esperar ~2 min, acceder a http://localhost:8080
3. ✅ Obtener contraseña con: `docker compose -f docker-compose.jenkins.yml logs jenkins | grep initialAdminPassword`
4. ✅ Agregar credenciales en Jenkins UI:
   - dockerhub-credentials (Usuario + Token)
   - kubeconfig-credentials (Secret file: ~/.kube/config)
   - gcp-sa-json (Secret file: GCP Service Account JSON)
5. ✅ Crear Multibranch Pipeline `circleguard` → apuntando al GitHub repo
6. ✅ Hacer push a rama `stage` para disparar primer build
7. ✅ Verificar deployment: `kubectl -n stage get pods`

## 🌐 Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│               Tu Máquina (Windows/Linux)                │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         Docker Container: Jenkins              │    │
│  │  • Multibranch Pipeline                        │    │
│  │  • Git + GitHub webhook                        │    │
│  │  • Docker CLI (mount socket)                   │    │
│  │  • kubectl (kubeconfig mount)                  │    │
│  │  • Gradle (en jars pre-compilados)            │    │
│  └────────────────────────────────────────────────┘    │
│                      │                                   │
│  Push a GitHub → Webhook → Jenkins dispara build       │
│                                                          │
└─────────────────────────────────────────────────────────┘
          │                          │
          ├──────────────────────────┼──────────────────┐
          │                          │                  │
          ▼                          ▼                  ▼
    ┌────────────┐        ┌──────────────────┐   ┌───────────┐
    │ Docker Hub │        │ GCP Project      │   │  kubectl  │
    │ (Push      │        │ (proyectoIngesoft)   │ (Deploy)  │
    │  images)   │        │ • Terraform      │   │           │
    │            │        │ • GKE Cluster    │   │ circle-   │
    └────────────┘        └──────────────────┘   │ guard-    │
                               ▲                  │ cluster   │
                               │                  └───────────┘
                          Creación de                   ▲
                          recursos                      │
                                                    Deployment
```

## 📞 Soporte

Para más detalles: ver [JENKINS_LOCAL_SETUP.md](./JENKINS_LOCAL_SETUP.md)

---

**Estado**: ✅ Jenkins local completamente configurado y listo para usar.  
**Destino de Deployments**: GCP `proyectoIngesoft` (circle-guard-cluster)  
**6 Microservicios**: auth, identity, promotion, gateway, form, notification
