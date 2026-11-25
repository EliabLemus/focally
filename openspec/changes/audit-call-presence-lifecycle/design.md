# Design: audit-call-presence-lifecycle

## Ruta real a auditar

La ruta de producción actual es:

1. `AppDelegate.applicationDidFinishLaunching` crea `MediaDeviceCallDetector`, instala `onCallStarted`/`onCallEnded` y llama `start()` (`OnItFocusApp.swift:64-70, 99-109`).
2. El detector consulta CoreAudio, clasifica el cliente y llama los callbacks (`MediaDeviceCallDetector.swift:250-269`). Esos callbacks están declarados `deprecated` en el propio detector (`:73-78`), por lo que el contrato operativo está contradicho por su implementación.
3. `PresenceCoordinator.callStarted` converge en `applyActiveCall`; Slack se intenta solo si `callStatusEnabled && slackService.isEnabled` (`PresenceCoordinator.swift:379-399`) y DND se solicita según la preferencia.
4. `applyIdle` restaura/limpia Slack y libera únicamente DND poseído por Focally (`PresenceCoordinator.swift:411-420, 481-505`).

La auditoría debe fijar una sola transición de dominio, no introducir un segundo coordinador ni duplicar estado.

## Decisiones de contrato

1. **Push canónico, no polling nuevo.** `MediaDeviceCallDetector` ya posee las
   semánticas de inicio/fin con debounce y grace period. Sus callbacks
   `onCallStarted` y `onCallEnded` se conservarán como la API productiva y se
   les quitará la anotación `deprecated`; `CaptureSignaling.currentSnapshot()`
   sigue siendo una consulta corroborante, no un reemplazo de transiciones.
2. **Una instalación.** `AppDelegate.applicationDidFinishLaunching` instala un
   único consumidor de esos callbacks. No se agrega un segundo detector ni un
   bucle de polling.
3. **Foco inyectado después de construir el timer.**
   `DefaultPresenceCoordinator.shared` hoy se crea antes de `timerService` y
   queda con `sessionController == nil`. El coordinador recibirá el
   `FocusTimerService` ya construido mediante una sola operación de attach en
   launch; no se reconstruye el singleton ni se duplican coordinadores.

## Modelo de transición

Cada cambio de captura produce un `CallPresenceTransition` interno con:

- `phase`: `started`, `ended`, `noticeStarted`, `noticeEnded`, o `effectFailed`.
- `source`: identidad de cliente ya existente, sin registrar URL, asunto de calendario ni texto de Slack.
- `mode`: `call` o `notice`.
- `effects`: resultado explícito de Slack, DND y foco: `applied`, `skipped(reason)`, `released` o `failed(reason)`.

Esto no es una nueva capa persistente. Es un valor de diagnóstico enviado al logger y expuesto al estado local mínimo de la app mientras está vigente.

## Observabilidad

El wrapper actual `Logger.info(_ message: String)` convierte interpolaciones en privadas. Los eventos de ciclo de vida SHALL usar mensajes estáticos con campos no sensibles declarados públicos, o códigos de evento con valores booleanos/enum. Ejemplo válido:

```swift
osLogger.info("call_presence phase=started mode=call slack=applied dnd=applied focus=skipped")
```

Nunca se registran token, texto de estado Slack, URL, título de evento ni identificadores de calendario.

## Semántica de notice

`notice` no es una llamada completa. Por diseño no activa Slack, DND ni pausa de foco. Para que no sea indistinguible de una falla, Focally SHALL mostrar una indicación local breve y accesible mientras exista la captura, por ejemplo en el menú/panel de estado: “Micrófono en uso — aviso”. La UI de Settings SHALL explicitar exactamente esos efectos omitidos.

## Verificación E2E

El E2E se ejecuta en la Mac del owner, no en Nexus. Una llamada de navegador sin evento de calendario en modo `call` debe producir los tres efectos y, al colgar, revertirlos. El resultado se registra por una secuencia de códigos públicos de transición y por observación directa de Slack, Focus y timer. Si un servicio no está configurado, el caso se marca `skipped(notConfigured)`; no se cuenta como éxito del efecto.
