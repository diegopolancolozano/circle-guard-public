# Bonificaciones: qué se puede documentar sin nube y qué no

No todo el bloque de bonificaciones exige tener múltiples proveedores cloud activos. Hay una parte que sí puede quedar bien documentada, y otra que requiere despliegue real para demostrarla.

## Se puede hacer sin nube real

### Multi-cloud

- Diseñar una arquitectura preparada para dos proveedores.
- Documentar estrategia de respaldo, failover y balanceo.
- Comparar costos y latencias con tablas estimadas o evidencias históricas.

### Service mesh

- Definir la topología del mesh.
- Documentar mTLS, traffic shifting y políticas de retry.
- Dejar manifiestos o diseño de referencia aunque no se ejecute.

### Chaos engineering

- Diseñar experimentos de caos.
- Documentar hipótesis, métricas esperadas y criterios de éxito.
- Incluir una matriz de riesgos y mejoras esperadas.

### FinOps

- Preparar un análisis de costos.
- Documentar políticas de ahorro y escalado.
- Definir dashboards y métricas de utilización.

## Requiere nube o infraestructura real para valer como demo

- Despliegue activo en dos clouds.
- Balanceo real entre proveedores.
- Medición real de rendimiento entre clouds.
- Ejecución de experimentos de caos sobre un clúster vivo.
- Dashboards de costos reales de infraestructura.

## Recomendación para la entrega

Si todavía no podés usar nube, entregá:

- diseño,
- diagramas,
- decisiones técnicas,
- plantillas de validación,
- y evidencias locales o de laboratorio.

Eso te cubre buena parte del criterio, aunque la demo completa del bono quede como trabajo futuro.
