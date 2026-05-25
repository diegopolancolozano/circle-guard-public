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

## OWASP ZAP / seguridad dinámica

Para completar la rúbrica se recomienda agregar:

- una ejecución automatizada contra el ambiente `stage`,
- reportes HTML o JSON archivados como artefactos,
- fallos por vulnerabilidades altas o críticas.

## SonarQube

Aunque no esté conectado todavía, el documento deja claro el flujo esperado:

- análisis estático,
- quality gate,
- bloqueo de release si hay deuda crítica.

## Criterios de aceptación de calidad

- Las pruebas unitarias pasan sin fallos.
- Las pruebas de integración cubren los endpoints críticos.
- Las pruebas E2E validan el recorrido principal.
- Locust genera reportes de rendimiento.
- Los resultados quedan archivados por build.
