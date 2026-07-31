# SPEC_NATIVE_FOCUS_INTEGRATION.md

## Objetivo
Hacer que la integración de Focus / Do Not Disturb deje de sentirse “invisible” o dudosa. Para Focally, la activación de Focus debe dar una **confirmación visual global y confiable**, no solo un estado interno de la app o una suposición de que las notificaciones fueron silenciadas.

## Problema actual
La implementación actual de Focally activa un estado tipo DND por backend, pero el usuario no recibe una confirmación visual global clara en macOS. Slack muestra su propia `Z`, pero el resto del sistema no da una señal suficientemente obvia dentro del flujo real del usuario.

Si el usuario no puede confirmar visualmente que macOS entero está en Focus, la feature se percibe como poco confiable y pierde valor principal.

## Hallazgos de research

### Competidores / referencias

#### Session
- Documenta automatización de Focus en Mac.
- Históricamente usó AppleScript/keyboard shortcut.
- Hoy recomienda integración vía **Apple Shortcuts + Apple Focus**.
- Su propia guía pide que el usuario haga visible el ícono de Focus / crescent moon en el menú bar para tener confirmación visual del sistema.

#### Pomotto
- Vende exactamente el beneficio “timer starts, notifications stop”.
- Se apoya explícitamente en **macOS Do Not Disturb / Focus modes**.
- Vive en el menú bar y posiciona esa integración como parte del core del producto.

#### Apple
- Apple expone la activación manual de Focus por Control Center / Focus y soporta un indicador nativo del sistema cuando el icono está visible en la barra.
- No se encontró una API pública, estable y clara para que una app de terceros “dibuje” o fuerce por sí sola un indicador global nativo distinto al mecanismo normal del sistema.

## Conclusión de producto
La forma correcta de resolver esto en Focally no es solo “tener un badge dentro de la app”, sino **integrarse con el Focus nativo del sistema** y diseñar onboarding/feedback para que el usuario vea la señal global real de macOS.

---

## Opciones de implementación evaluadas

### Opción A — Mantener hack backend actual (`notificationcenterui` / prefs)
**Descripción**
Seguir activando DND vía preferencias/scripting interno como hoy.

**Pros**
- Ya existe base implementada.
- Poca fricción de implementación adicional.
- No exige setup manual inicial complejo.

**Contras**
- Confirmación visual global poco confiable.
- Fragilidad ante cambios internos de macOS.
- Se basa en comportamiento no ideal para una feature central.
- Difícil comunicar con claridad al usuario qué Focus exacto quedó activo.

**Veredicto**
Útil como fallback temporal, pero **no** debería ser la estrategia principal.

---

### Opción B — Integración nativa con Apple Focus vía Shortcuts
**Descripción**
Focally dispara shortcuts configurables (`focally_session_start`, `focally_session_end` o equivalentes) que activan/desactivan un Focus nativo del usuario (por ejemplo `Do Not Disturb`, `Work`, u otro custom).

**Pros**
- Usa mecanismos soportados por Apple en el ecosistema actual.
- Permite activar un Focus real del sistema, visible fuera de Focally.
- El usuario puede elegir su modo (`Do Not Disturb`, `Work`, custom).
- Mejor compatibilidad conceptual con lo que hacen apps como Session.
- Permite onboarding claro y comprobable con botón de test.

**Contras**
- Requiere setup inicial del usuario si no existe shortcut.
- Añade fricción UX si el onboarding no está bien diseñado.
- Necesita manejar estados de error: shortcut no existe, permisos, nombre incorrecto.

**Veredicto**
**Recomendada como estrategia principal.** Es la mejor mezcla de confiabilidad, visibilidad y alineación con macOS.

---

### Opción C — UI scripting del Control Center / Focus UI
**Descripción**
Intentar abrir/interactuar el Control Center o los controles visibles de Focus mediante automatización/UI scripting.

**Pros**
- Puede parecer “más nativo” a simple vista.

**Contras**
- Muy frágil.
- Dependiente de idioma, layout, permisos de Accessibility y cambios visuales del sistema.
- Difícil de testear y mantener.
- Mala base para una feature principal.

**Veredicto**
**No recomendada.** Solo serviría como experimento, no como arquitectura de producto.

---

## Recomendación

### Estrategia final recomendada
1. **Primary path:** Apple Focus vía Shortcuts.
2. **Fallback opcional:** backend DND existente mientras completamos la transición o para usuarios que no configuren Shortcuts.
3. **Feedback visible en dos capas:**
   - capa global: Focus nativo de macOS visible en el menú bar del sistema
   - capa local: estado claro dentro de Focally (dropdown + ventana principal)

Esto convierte la feature en algo que el usuario realmente puede confiar.

---

## UX propuesta

### Settings → Focus Integration
Agregar una sección nueva o expandir la actual con:
- **Enable Focus Integration**
- **Mode**:
  - Apple Focus (Recommended)
  - Legacy DND Fallback
- **Focus to activate**:
  - Do Not Disturb
  - Work
  - Personal
  - Custom shortcut / custom focus
- **Session start action**
- **Session end action**
- **Test activation**
- **Test deactivation**

### Onboarding / Helper text
Copys importantes:
- “For global visual confirmation, pin the macOS Focus icon to your menu bar.”
- “Focally can activate a real macOS Focus mode when your timer starts.”
- “Use Test Activation to verify the system icon appears.”

### Runtime feedback inside Focally
Durante sesión activa:
- Badge visible: `Focus ON` o `DND ON`
- Subtexto opcional: `macOS Focus active`
- Estado visible en:
  - menu bar dropdown
  - main timer screen

### Failure states
Si falla la integración:
- `Focus shortcut not found`
- `Focus activation could not be confirmed`
- `Using legacy fallback`
- CTA: `Open setup guide`

---

## Scope funcional propuesto

### Fase 1 — MVP funcional
- Permitir integración con Apple Focus vía Shortcuts.
- Permitir elegir nombre/identidad del shortcut o focus.
- Botones `Test Activation` / `Test Deactivation`.
- Mostrar estado interno claro en Focally.
- Documentar que el usuario debe fijar el icono de Focus al menú bar para la confirmación global.

### Fase 2 — Robustez
- Detectar si shortcuts faltan o fallan.
- Fallback automático a modo legacy si el usuario lo habilita.
- Mejor copy de diagnóstico.

### Fase 3 — Pulido
- Wizard guiado de setup.
- Soporte para diferentes Focus por tipo de sesión.
- Métrica interna de éxito/fallo de activación.

---

## Criterios de aceptación del rediseño
- [ ] Focally ofrece una ruta explícita de **Native macOS Focus Integration** en Settings.
- [ ] El usuario puede probar activación/desactivación antes de usarlo en una sesión real.
- [ ] La app comunica claramente que la confirmación visual global depende del Focus nativo visible en el menú bar del sistema.
- [ ] Durante una sesión, Focally muestra también un estado local visible y legible.
- [ ] Si la integración falla, Focally muestra error/diagnóstico en vez de fingir que todo salió bien.
- [ ] La feature deja de depender exclusivamente del hack actual de backend como experiencia principal.

---

## Archivos que probablemente tocará la implementación
- `Focally/Services/DNDService.swift`
- `Focally/Services/FocusTimerService.swift`
- `Focally/Views/MenuBar/MenuBarDropdownView.swift`
- `Focally/Views/Settings/GeneralSettingsView.swift`
- `Focally/Views/Settings/SettingsPage.swift`
- `Focally/Services/NotificationService.swift`
- potencialmente un nuevo servicio tipo `FocusIntegrationService.swift`

---

## Riesgos
- Apple Shortcuts puede introducir una primera configuración menos “mágica”.
- Puede haber edge cases por nombres de shortcuts/focus personalizados.
- La activación podría ser asíncrona o no confirmable de forma perfecta en todos los casos.

## Mitigaciones
- Botón de test.
- Guía de setup simple.
- Fallback legacy opcional.
- Messaging honesto cuando no se puede confirmar el estado.

---

## Decisión ejecutiva
Si esta feature es principal, **Focally debe pivotar de “hack de DND invisible” a “Native Focus Integration visible y comprobable”**.

No basta con silenciar cosas: el usuario necesita ver que macOS entero entró en modo focus.

Ese debería ser el estándar de la v0.6.6+ para que la feature realmente sirva.
