# Tasks: audit-call-presence-lifecycle

**Estado: Draft.** No implementar ni publicar sin aprobación explícita del owner.

## 1. Baseline y trazabilidad

- [ ] 1.1 Reproducir inicio y fin de una llamada real de navegador en la Mac del owner con `log stream --style compact --level info --predicate 'subsystem == "app.focally.mac" AND category == "CallDetection"'`. Guardar solo fases/códigos, no datos privados. Verificación: línea de baseline con inicio y resultado de fin o ausencia documentada.
- [ ] 1.2 Mapear la ruta efectiva desde `AppDelegate` hasta Slack, DND y pausa de foco, incluido cada guard y retorno temprano. Hallazgo ya confirmado: `DefaultPresenceCoordinator.shared` se crea sin `sessionController`, por lo que pausa/reanudación nunca corre en producción. Verificación: tabla de símbolos reales archivo:línea; ningún supuesto basado solo en nombres.
- [ ] 1.3 Confirmar configuración efectiva de llamada y estado de integración Slack en la Mac del owner sin revelar secretos, ANTES de declarar falla de Slack/DND. Verificación: cada flag se clasifica como enabled/disabled y Slack como connected/notConnected.

## 2. Contrato y observabilidad

- [ ] 2.1 Canonizar `onCallStarted`/`onCallEnded` como API push: remover `deprecated`, documentar que `currentSnapshot()` es corroborativo e instalar un único consumidor productivo. Verificación: no queda `deprecated` sobre los callbacks; tests de inicio y fin ejercen el contrato push.
- [ ] 2.1a Adjuntar `FocusTimerService` al singleton de presencia después de construirlo, sin reconstruir el singleton. Verificación: test de wiring o de attach; una llamada `.call` con sesión activa pausa y reanuda en la ruta productiva.
- [ ] 2.2 Emitir eventos `call_presence` públicos, estructurados y no sensibles con fase/modo/resultados. Verificación: prueba de logger o adaptador; `log stream --level info` muestra eventos legibles en una ejecución manual.
- [ ] 2.3 Incluir motivos estables para efectos omitidos o fallidos: al menos `notConnected`, `noticeMode`, `externallyOwned`, `notConfigured` y `requestFailed`. Verificación: tests por motivo aplicable.
- [x] 2.4 Diagnóstico in-app (aprobado por el owner): `CallPresenceDiagnostics` — almacén `@Observable` en memoria, acotado, solo códigos estáticos con marca de tiempo — registra cada evento emitido por `emitCallPresenceEvent` conservando OSLog y el sink de pruebas; Calls settings (`CallDetectionSettingsView`) muestra el historial reciente con copys en/es/pt. Verificación: `CallPresenceDiagnosticsTests` (orden, límite, wiring del coordinador) + `CallPresenceCoordinatorTests` en verde con `xcodebuild test -scheme Focally -destination 'platform=macOS'`; `git diff --check` limpio. Revisión de UI en la Mac del owner pendiente del E2E 5.3.

## 3. Efectos y cleanup

- [ ] 3.1 Slack: devolver resultado de `setStatus` y de restore/clear a PresenceCoordinator; no ocultar fallo de red/API. Verificación: fake Slack que falla produce `failed(requestFailed)` y no `applied`.
- [ ] 3.2 DND: conservar ownership actual y emitir resultado verificable de activación/release. Verificación: tests de DND propio y externo; el externo no se apaga.
- [ ] 3.3 Foco: confirmar el controlador real usado por `PresenceCoordinator`; pausar solo una sesión activa y reanudar solo si Focally la pausó. Verificación: test de sesión activa y de ausencia de sesión.
- [ ] 3.4 Cierre: asegurar que la transición de fin alcanza los tres efectos aun cuando uno falle. Verificación: test donde Slack falla al limpiar pero DND y foco se liberan.

## 4. Notice visible

- [ ] 4.1 Añadir indicador local accesible para `noticeStarted`/`noticeEnded`. Verificación: prueba de estado + revisión de UI en menú/panel.
- [ ] 4.2 Cambiar el copy de Settings para describir `notice` como aviso local y enumerar que no cambia Slack, DND ni foco. Verificación: snapshot o inspección de la vista y build.

## 5. Pruebas y aceptación

- [ ] 5.1 Unit tests para cada requisito y escenario del delta; no usar solo logs como aserción de efectos. Verificación: `xcodebuild test -scheme Focally -destination 'platform=macOS'`.
- [ ] 5.2 Build de producción. Verificación: `xcodebuild build -scheme Focally -destination 'platform=macOS'`.
- [ ] 5.3 E2E único y reutilizable en la Mac del owner: navegador en `.call` → Slack/DND/foco; colgar → restore ≤10 s; `.notice` → indicador local sin efectos. Verificación: checklist con evidencia de las seis transiciones/resultados.
- [ ] 5.4 Revisión adversarial del diff congelado y re-ejecución de la suite si cambia código. Verificación: hallazgos resueltos o documentados, build y tests finales verdes.

## Riesgo explícito

La Mac del owner es la fuente de verdad para E2E. Nexus puede compilar y ejecutar unit tests, pero no puede afirmar funcionamiento de llamadas, DND o Slack en la M3 sin esa evidencia.