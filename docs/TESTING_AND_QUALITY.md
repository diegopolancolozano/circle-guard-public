# Pruebas y calidad

Esta guía resume el esquema de pruebas y calidad para documentar el proyecto de forma completa.

## Pirámide de pruebas

- **Unitarias**: lógica de servicios, validadores y utilidades.
- **Integración**: interacción entre controller, service, repository y clientes externos simulados.
- **E2E**: flujos completos de usuario con el sistema desplegado.
- **Performance**: carga y estrés con Locust.
- **Seguridad**: pruebas de vulnerabilidades y validación de endurecimiento.

## Matriz de cobertura

| Tipo de prueba | Objetivo | Evidencia |
|:---|:---|:---|
| Unitarias | Verificar reglas de negocio aisladas | Reporte de Gradle/JUnit |
| Integración | Validar contratos internos | XML/HTML de test results |
| E2E | Cubrir flujos críticos | Logs y artefactos de pipeline |
| Performance | Medir latencia y throughput | CSV/JSON de Locust |
| Seguridad | Detectar vulnerabilidades | Reporte de escaneo |

## Calidad automatizada

- Generar reportes de cobertura en cada ejecución relevante.
- Guardar evidencias por versión.
- Ejecutar las pruebas en la pipeline por etapas.
- Separar pruebas rápidas de pruebas costosas.

Cobertura actual:

- JaCoCo habilitado en subprojects (HTML + XML).
- Reportes típicos: `services/*/build/reports/jacoco/test/`.

## OWASP ZAP / seguridad dinámica

Implementación actual:

- Script: `scripts/ci/run-owasp-zap.sh`
- Reportes: `tests/security/results/zap-*.{html,json,md}`
- Ejecutado en pipeline `full` con el servicio gateway expuesto via port-forward.

Buenas prácticas recomendadas:

- una ejecución automatizada contra el ambiente `stage`,
- reportes HTML o JSON archivados como artefactos,
- fallos por vulnerabilidades altas o críticas.

## Trivy (vulnerabilidades en contenedores)

Implementación actual:

- Script: `scripts/ci/run-trivy.sh`
- Reportes: `tests/security/results/trivy-*.{json,txt}`
- Ejecutado en pipeline `full` antes de deploy.

## SonarQube

Implementación actual:

- Stage "Static Analysis (SonarQube)" en pipeline.
- Requiere `SONAR_HOST_URL` y `SONAR_TOKEN`.
- Puede integrarse con quality gate si el servidor lo configura.

## Criterios de aceptación de calidad

- Las pruebas unitarias pasan sin fallos.
- Las pruebas de integración cubren los endpoints críticos.
- Las pruebas E2E validan el recorrido principal.
- Locust genera reportes de rendimiento.
- Los resultados quedan archivados por build.
