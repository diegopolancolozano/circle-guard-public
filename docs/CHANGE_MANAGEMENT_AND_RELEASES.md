# Change Management y Release Notes

Este documento describe un proceso simple y reproducible para aprobar, versionar y publicar cambios.

## Proceso de Change Management

1. Se registra el cambio en una historia o tarea.
2. Se implementa en una rama de trabajo corta.
3. Se valida con pruebas automáticas y revisión de logs.
4. Se integra primero en `dev`, luego en `stage` y finalmente en `main`.
5. Se generan evidencias y notas de versión.

## Política de promoción

- `dev`: validación continua de cambios.
- `stage`: integración y pruebas funcionales/performance.
- `main`: release estable con evidencias y notas de versión.

## Versionado semántico

Se recomienda usar `MAJOR.MINOR.PATCH`:

- `MAJOR`: cambios incompatibles.
- `MINOR`: nuevas capacidades compatibles.
- `PATCH`: correcciones y ajustes menores.

## Tags de release

Cada release estable debería quedar etiquetada en Git:

```bash
git tag -a v1.2.3 -m "CircleGuard v1.2.3"
git push origin v1.2.3
```

## Plan de rollback

Si una release falla:

- volver al tag estable anterior,
- redeploy del manifiesto o imagen previa,
- conservar logs y métricas del incidente,
- registrar causa raíz y acción correctiva.

## Plantilla mínima de release notes

```markdown
## v1.2.3
- Feature: ...
- Fix: ...
- Tests: unit, integration, e2e, performance
- Infra: dev/stage/prod
- Risks: ...
```

## Automatización recomendada

- Generar release notes desde commits y cambios de rama.
- Adjuntar artefactos de pruebas y métricas.
- Publicar evidencia en cada merge a `main`.
