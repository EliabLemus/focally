# Delta Spec: call-presence-lifecycle (ADDED)

## ADDED Requirements

### Requirement: La transición de llamada SHALL tener una traza pública y no sensible

Para cada inicio, fin, aviso o fallo de efecto, Focally SHALL emitir un evento de ciclo de vida legible mediante `log stream --level info`, con fase, modo y resultado de Slack, DND y foco. El evento SHALL NOT incluir texto de estado Slack, token, URL, título o identificador de calendario.

#### Scenario: Inicio de llamada completa
- WHEN una señal se clasifica como modo `call`
- THEN se emite un evento `phase=started` que declara para cada efecto `applied`, `skipped(reason-code)` o `failed(reason-code)` antes de que transcurra un segundo desde la transición

#### Scenario: Fin de llamada
- WHEN termina la señal que sostenía una llamada completa
- THEN se emite un evento `phase=ended` que declara el resultado de restaurar Slack, liberar DND y reanudar foco

### Requirement: Los eventos SHALL ser legibles dentro de la app sin terminal

El historial reciente de códigos `CallPresenceEvent` SHALL estar disponible en Calls settings a través de un almacén diagnóstico observable, en memoria y acotado (se descartan los eventos más antiguos al superar el límite). La superficie SHALL mostrar exclusivamente códigos opacos estáticos con marca de tiempo y SHALL NOT persistir el historial en UserDefaults ni en disco, ni incluir bundle IDs, títulos de reuniones/eventos, texto de estado Slack, URLs, tokens o contenido de OSLog. El registro diagnóstico SHALL conservar el logging OSLog de producción y el sink de pruebas existentes.

#### Scenario: Consultar la actividad de llamadas sin terminal
- WHEN una señal genera eventos de presencia de llamada
- THEN Calls settings muestra los códigos de evento recientes con su marca de tiempo, en orden de ocurrencia, sin requerir `log stream`

#### Scenario: Historial acotado y volátil
- WHEN se registran más eventos que el límite del almacén
- THEN los más antiguos se descartan conservando los más recientes en orden, y al reiniciar Focally el historial comienza vacío

#### Scenario: Diagnóstico in-app sin degradar la traza existente
- WHEN `DefaultPresenceCoordinator.emitCallPresenceEvent` emite un evento de producción
- THEN el evento se registra en el almacén in-app y además se mantiene el logging OSLog y el sink de pruebas con el mismo código

### Requirement: La ruta de producción SHALL usar un contrato de transición no deprecado

`MediaDeviceCallDetector.onCallStarted` y `onCallEnded` SHALL ser la API push canónica de transición: no estarán marcados `deprecated` y conservarán sus semánticas existentes de debounce/grace. `CaptureSignaling.currentSnapshot()` SHALL mantenerse como consulta corroborante y SHALL NOT sustituir el contrato push. `OnItFocusApp` SHALL conectar esa API a `PresenceCoordinator` una sola vez.

#### Scenario: Inicio de la aplicación
- WHEN la aplicación termina de lanzar
- THEN instala exactamente un consumidor de transiciones de llamada, adjunta el controlador de sesión de foco ya construido y comienza la observación del detector

#### Scenario: Inicio con sesión de foco disponible
- WHEN `FocusTimerService` ya fue construido durante el lanzamiento
- THEN `DefaultPresenceCoordinator.shared` recibe ese mismo objeto como `CallFocusSessionControlling`, por lo que una llamada completa puede pausar y luego reanudar una sesión activa

### Requirement: Una llamada completa SHALL aplicar o explicar cada efecto configurado

Con `CallDetectionSettings.callStatusEnabled`, `enableDNDDuringCalls` y `pauseFocusDuringCalls` activos, una transición `call` SHALL intentar el efecto correspondiente. Si no puede hacerlo, SHALL registrar `skipped` o `failed` con razón estable y accionable; no puede aparentar éxito.

#### Scenario: Slack no está conectado
- WHEN inicia una llamada completa con `callStatusEnabled == true` y `slackService.isEnabled == false`
- THEN Slack queda `skipped(notConnected)` en la traza, mientras DND y foco se siguen procesando independientemente

#### Scenario: Llamada completa con integraciones configuradas
- WHEN inicia una llamada completa y Slack, DND y una sesión de foco están disponibles
- THEN Slack recibe el status configurado, DND queda activo y la sesión de foco queda pausada; la traza informa los tres efectos como `applied`

### Requirement: El fin SHALL liberar solo los efectos poseídos y reanudar foco

Al finalizar una llamada completa, Focally SHALL restaurar o limpiar el status que haya escrito, desactivar exclusivamente el DND que posea y reanudar una sesión que él haya pausado. Cada operación SHALL tener resultado verificable.

#### Scenario: Colgar una llamada completa
- WHEN termina una llamada que activó DND, publicó status y pausó una sesión
- THEN dentro de 10 segundos DND queda liberado, el status de Focally deja de estar activo y la sesión queda reanudada; la traza incluye `phase=ended`

#### Scenario: DND preexistente del usuario
- WHEN DND ya estaba activo antes de iniciar una llamada
- THEN al colgar Focally no lo desactiva y la traza informa `skipped(externallyOwned)` para su liberación

### Requirement: El modo notice SHALL ser visible y no aplicar presencia completa

Una captura en modo `notice` SHALL mostrar estado local accesible mientras exista la captura y SHALL no aplicar Slack, DND ni pausa de foco. Settings SHALL describirlo como “aviso local” y enumerar los efectos que no realiza.

#### Scenario: Captura de navegador sin reunión en modo notice
- WHEN una captura se clasifica `notice`
- THEN la UI muestra “Micrófono en uso — aviso”, la traza incluye `phase=noticeStarted`, y Slack/DND/foco quedan `skipped(noticeMode)`

#### Scenario: Termina una captura en modo notice
- WHEN deja de existir la captura de aviso
- THEN el indicador local desaparece y se emite `phase=noticeEnded`, sin intentar restauraciones de Slack, DND o foco

### Requirement: La aceptación E2E SHALL demostrar efectos reales y cierre

El repositorio SHALL mantener un procedimiento o script reutilizable para ejecutar en la Mac del owner una llamada real de navegador sin evento de calendario. La validación SHALL comprobar inicio y cierre mediante trazas públicas y superficies reales de Slack, Focus y timer.

#### Scenario: E2E de llamada de navegador
- WHEN el operador pone `uncorroboratedBrowserCapture=call`, inicia una llamada de navegador, espera la transición y luego cuelga
- THEN evidencia el status de Slack, DND y pausa durante la llamada; dentro de 10 segundos de colgar evidencia que los tres efectos se restauraron o una razón `failed` explícita