# Delta spec: call-emoji-customization (nueva capability)

## ADDED Requirements

### Requirement: El usuario puede personalizar el emoji de Slack por cliente de llamada

El sistema SHALL permitir asignar un shortcode de emoji de Slack a cada cliente de llamada conocido (Google Meet/Chrome, Firefox, Edge, Slack, Zoom, Teams, Discord) y al cliente desconocido (Unknown Client), persistiendo los overrides entre lanzamientos.

#### Scenario: Override para Google Meet

- **WHEN** el usuario asigna `:google-meet:` al cliente `com.google.chrome` y entra a una llamada de Meet en Chrome
- **THEN** el estado de Slack usa `:google-meet:` como emoji de la llamada

#### Scenario: Override para Unknown Client

- **WHEN** el usuario asigna `:google-meet:` al cliente desconocido y una llamada es atribuida sin match de catálogo
- **THEN** el estado de Slack usa el emoji configurado en vez de `:phone:`

#### Scenario: Persistencia entre lanzamientos

- **WHEN** el usuario configura overrides, cierra y reabre Focally
- **THEN** los overrides configurados siguen activos sin re-configuración

### Requirement: Los overrides reemplazan solo el emoji, no la atribución

Un override SHALL modificar únicamente el campo `emoji` del `CallClient` resuelto; el matching por bundle-id prefix y el `displayName` MUST permanecer code-defined y sin cambios.

#### Scenario: Override no altera el matching

- **WHEN** existe un override con un shortcode distinto para `com.google.chrome`
- **THEN** `CallClientCatalog.client(for: "com.google.chrome.helper")` sigue resolviendo al mismo cliente (mismo bundlePrefix y displayName) con el emoji override

#### Scenario: Shortcode inexistente en el workspace

- **WHEN** el usuario escribe un shortcode que no está en `workspaceEmojiCodes` cargados y guarda
- **THEN** la UI muestra una advertencia inline (no bloqueante) pero el override se guarda igual
- **AND** al publicar, si la API de Slack rechaza el shortcode, el sistema registra un warning en unified logging con el shortcode rechazado

### Requirement: Arc resuelve a Google Meet por defecto

El catálogo default SHALL incluir el prefijo `company.thebrowser` (Arc) mapeado a `:google-meet:`, de modo que una llamada de Meet en Arc deje de caer en Unknown Client.

#### Scenario: Llamada de Meet en Arc

- **WHEN** un proceso `company.thebrowser.*` captura micrófono durante una llamada
- **THEN** la llamada se atribuye a Arc con emoji `:google-meet:` sin configuración previa del usuario

### Requirement: La configuración vive en Call Detection Settings

La sección de personalización SHALL vivir en la vista de settings de detección de llamadas existente (`CallDetectionSettingsView`), con un picker de búsqueda que sugiera shortcodes del workspace del usuario, sin introducir una vista nueva de primer nivel.

#### Scenario: Picker sugiere emojis del workspace

- **WHEN** el usuario abre el picker de un cliente con el token de Slack conectado
- **THEN** la búsqueda filtra entre `workspaceEmojiCodes` ya cargados y muestra coincidencias mientras escribe

#### Scenario: Sin token de Slack conectado

- **WHEN** el picker se abre sin emoji de workspace cargados
- **THEN** el usuario aún puede escribir un shortcode manualmente y guardarlo (la validación contra el workspace es best-effort, no bloqueante)
