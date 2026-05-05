# Focally Backlog Status

## 1. Baseline actual

- `main == origin/main`
- `HEAD`: `c2cac11`
- Tag/release actual: `v0.6.4`
- `project.yml`: `MARKETING_VERSION = 0.6.4`, `CURRENT_PROJECT_VERSION = 13`
- El baseline publicado va por delante de parte de la documentación: `README.md` todavía muestra `0.4.1`

## 2. Prioridad actual: testing first

La prioridad inmediata del repo es consolidar testing antes de más trabajo estructural. Ya existen artefactos locales de pruebas que no forman parte de `HEAD` (`FocallyTests/`, `FocallyUITests/`, `tests/`, además de specs/reportes asociados), así que primero conviene decidir qué entra al baseline y validarlo.

Orden recomendado:

1. `TASK-023` — unit tests
2. `TASK-027` — batería básica XCUITest
3. `TASK-028` — E2E UI tests
4. `TASK-021` — `SettingsStore` / source of truth
5. `TASK-016` — migración a `@Observable`

## 3. Tasks activas

- `TASK-023`: agrega la red base de unit tests; hoy existe trabajo local, pero no está integrado al baseline publicado.
- `TASK-027`: define la capa mínima de XCUITest; el spec local ya documenta bloqueos y alcance real.
- `TASK-028-UI-AUTOMATED-TESTS`: expande hacia flujos E2E completos, pero depende de aclarar primero qué parte del testing local se integra de verdad.
- `TASK-021`: sigue vigente como refactor estructural para unificar settings, pero debe ir después de estabilizar pruebas.
- `TASK-016`: sigue vigente como modernización arquitectónica, pero no debería adelantarse a la red de testing.

## 4. Tasks históricas / superseded

Buena parte de las tasks previas ya quedó absorbida por releases posteriores hasta `v0.6.4`. Algunas specs antiguas son históricas o fueron refinadas/reemplazadas por specs más nuevas, por lo que no conviene usarlas como backlog operativo principal sin revisar su relación con el estado actual del código.

## 5. Working tree local de tests

- Existen cambios locales y no integrados en `FocallyTests/`, `FocallyUITests/` y `tests/`.
- También existen archivos locales de soporte y reporte ligados a testing, incluyendo `COMPLETED_SPECS_TEST_REPORT.md`, `TEST_RESULTS_FINAL.md`, `tasks/TASK-027.md` y `tasks/TASK-028-UI-AUTOMATED-TESTS.md`.
- Mientras esos artefactos no entren a `HEAD`, el backlog debe asumir que la prioridad es decidir, limpiar e integrar testing antes de abrir más trabajo estructural.
