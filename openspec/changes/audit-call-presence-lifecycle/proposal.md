# Proposal: audit-call-presence-lifecycle

## Why

La evidencia de la Mac del owner del 18 de noviembre de 2026 demuestra una falla de extremo a extremo:

- Focally emitió dos eventos `CallDetection` al iniciar una llamada real.
- No hubo evidencia de que se modificara el estado de Slack, DND del sistema ni una sesión de foco.
- Al colgar, no hubo evidencia de una transición de fin.
- El comando de diagnóstico original omitía `--level info`, y el wrapper `Logger` publica interpolaciones como datos privados; por ello el log actual no permite distinguir `Call started`, `Call ended`, configuración efectiva ni resultado de cada efecto.
- El control `uncorroboratedBrowserCapture == .notice` está implementado para no producir DND, pausa ni estado Slack. No tiene una superficie de resultado visible, por lo que el usuario no puede distinguir “aviso” de “Focally no detectó nada”.

Antes de ampliar heurísticas de calendario o CoreAudio, hay que comprobar y cerrar el ciclo completo: señal → clasificación → PresenceCoordinator → Slack/DND/foco → cleanup → evidencia verificable.

## What Changes

- Añadir una auditoría ejecutable del pipeline de presencia de llamadas, con eventos públicos y estructurados que permitan identificar cada transición sin exponer contenido sensible de calendario o Slack.
- Añadir una superficie de diagnóstico in-app: un almacén observable en memoria, acotado y no sensible, que registra los códigos `CallPresenceEvent` recientes con marca de tiempo y se muestra en Calls settings, para que el owner no dependa de `log stream` en terminal.
- Consolidar el contrato de señal entre `MediaDeviceCallDetector` y `PresenceCoordinator`; la ruta de producción no dependerá de callbacks marcados `deprecated` como mecanismo decisorio.
- Hacer verificables los tres efectos de una llamada completa: estado Slack, DND de macOS y pausa/reanudación de foco, incluyendo los motivos de omisión.
- Definir el comportamiento observable de `notice`: una captura clasificada como aviso SHALL mostrar estado local explícito y SHALL no fingir una llamada completa.
- Corregir el cierre de llamada para que todas las posesiones adquiridas por Focally se liberen o se reporten como fallo verificable.
- Añadir una prueba E2E manual, reutilizable, en la Mac del owner. El E2E valida efectos reales, no solo logs ni mocks.

## Capabilities

### Added
- `call-presence-lifecycle`: contrato, trazabilidad y aceptación E2E para detección y presencia de llamadas.

## Impact

- `Sources/Focally/OnItFocusApp.swift`: cableado de producción del detector y coordinador.
- `Sources/Focally/Services/MediaDeviceCallDetector.swift`: emisión de inicio/fin y evidencia diagnóstica.
- `Sources/Focally/Services/PresenceCoordinator.swift`: clasificación, efectos y cleanup.
- `Sources/Focally/Services/SlackService.swift`: resultado de publicación/restauración de status.
- `Sources/Focally/Services/DNDService.swift` y `DNDReliabilityService.swift`: resultado verificable de DND.
- `Sources/Focally/Services/FocusIntegrationService.swift` o el controlador efectivo de sesión: pausa y reanudación.
- `Sources/Focally/Views/Settings/CallDetectionSettingsView.swift`: significado visible de modo aviso.
- Tests de detector, presencia, Slack, DND y foco; script o procedimiento E2E reproducible.

## Non-goals

- No cambia todavía la política calendar-first ni añade nuevas heurísticas de navegador.
- No usa automatización que eluda restricciones de macOS, Slack o navegadores.
- No publica, hace push ni modifica releases.

## Relación con cambios existentes

`calendar-first-call-detection` ya existe como borrador no versionado y propone una expansión amplia de señales y calendario. Este change lo antecede: no se debe implementar aquel borrador mientras no exista evidencia de que el ciclo actual señal → efectos → cierre funciona de extremo a extremo. Al cerrar esta auditoría, sus resultados podrán incorporarse como delta de aquel cambio o reemplazar sus requisitos que ya no sean válidos.