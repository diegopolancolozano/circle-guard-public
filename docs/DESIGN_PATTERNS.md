# Patrones de Diseno

Este documento identifica patrones existentes en la arquitectura y documenta los patrones implementados recientemente.

## Patrones existentes (arquitectura actual)

- **API Gateway**: el servicio de gateway centraliza validacion y acceso a servicios internos. Ejemplo: [services/circleguard-gateway-service/src/main/java/com/circleguard/gateway/service/QrValidationService.java](services/circleguard-gateway-service/src/main/java/com/circleguard/gateway/service/QrValidationService.java)
- **Repository**: uso de repositorios Spring Data para acceso a persistencia. Ejemplo: [services/circleguard-identity-service/src/main/java/com/circleguard/identity/repository/IdentityMappingRepository.java](services/circleguard-identity-service/src/main/java/com/circleguard/identity/repository/IdentityMappingRepository.java)
- **Layered Architecture (Controller -> Service)**: separacion de controladores y servicios. Ejemplo: [services/circleguard-auth-service/src/main/java/com/circleguard/auth/controller/LoginController.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/controller/LoginController.java) y [services/circleguard-auth-service/src/main/java/com/circleguard/auth/service/IdentityMappingService.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/service/IdentityMappingService.java)

## Patrones implementados (nuevos)

### 1) Resiliencia - Circuit Breaker

- **Implementacion**: Resilience4j aplicado al acceso remoto de identidad.
- **Clase**: [services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/RemoteIdentityMappingStrategy.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/RemoteIdentityMappingStrategy.java)
- **Beneficio**: evita fallos en cascada cuando Identity Service no responde y habilita fallback local.

### 2) Configuracion - Feature Toggle

- **Implementacion**: propiedad `features.identity.use-remote` para elegir estrategia de mapeo.
- **Clase**: [services/circleguard-auth-service/src/main/java/com/circleguard/auth/config/IdentityFeatureProperties.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/config/IdentityFeatureProperties.java)
- **Uso**: [services/circleguard-auth-service/src/main/java/com/circleguard/auth/service/IdentityMappingService.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/service/IdentityMappingService.java)
- **Beneficio**: habilita cambios de comportamiento sin redeploy, util para pruebas o incidentes.

### 3) Strategy

- **Implementacion**: estrategias local y remota para resolver IDs anonimos.
- **Interfaces y clases**:
  - [services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/IdentityMappingStrategy.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/IdentityMappingStrategy.java)
  - [services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/LocalIdentityMappingStrategy.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/LocalIdentityMappingStrategy.java)
  - [services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/RemoteIdentityMappingStrategy.java](services/circleguard-auth-service/src/main/java/com/circleguard/auth/identity/RemoteIdentityMappingStrategy.java)
- **Beneficio**: permite cambiar la estrategia de mapeo con bajo acoplamiento y sin tocar el controlador.

## Configuracion asociada

- Feature toggle: [services/circleguard-auth-service/src/main/resources/application.properties](services/circleguard-auth-service/src/main/resources/application.properties)
- Resilience4j: mismas propiedades en el archivo anterior.

## Resumen

Con estos cambios se cumplen los tres patrones solicitados:

- **Resiliencia**: Circuit Breaker
- **Configuracion**: Feature Toggle
- **Patron adicional**: Strategy
