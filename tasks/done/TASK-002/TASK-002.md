# TASK-002: Corrección de UI/UX en Focally

## Status
**PENDIENTE** — Requiere implementación

## Fecha
2026-04-30

## Priority
Alta — Usabilidad crítica

## Descripción

Focally tiene 4 issues críticos que afectan la experiencia de usuario. Estos deben corregirse antes de la siguiente release.

## Issues

### 1. No se cómo ver la versión que estoy corriendo

**Problema:** No hay forma visual de verificar qué versión de Focally está instalada en la máquina.

**Efecto:** Cuando Eliab necesita reportar bugs, no sabe qué versión está usando.

**Solución:**
- Agregar versión en el menú principal (flecha abajo del icono ⏳)
- Opción: "About Focally" en el menú contextual (right-click)
- Mostrar versión y build number en formato legible: "Focally v0.4.0 (build 67b9ab0)"

### 2. No hay donde elegir las tareas predeterminadas al iniciar sesión

**Problema:** Eliab puede configurar tareas predeterminadas en settings, pero al iniciar una sesión nuevo no hay opción para elegir cuál usar.

**Efecto:** Eliab tiene que volver a settings para elegir la tarea cada vez, lo cual rompe el flujo rápido.

**Solución:**
- En el panel principal de sesión (focus panel), agregar selector de tarea predeterminada
- Solo mostrar si hay más de una tarea predefinida
- Pre-seleccionar la primera tarea automáticamente
- Iniciar sesión con la tarea seleccionada inmediatamente

### 3. Modal de settings no se cierra al guardar

**Problema:** Al guardar las configuraciones, el modal permanece abierto. Eliab debe cerrarlo manualmente.

**Efecto:** UX confusa, hace doble-click extra innecesario.

**Solución:**
- Usar `presentationDetents` con `.gesture(.tapOutside)`
- O usar `sheet` con dismissible: `isPresented: $showSettings, onDismiss: {}`
- Aplicar dismiss en action sheet button en iOS, `NSPanel` en macOS
- iOS: `.presentationDetents([.medium], combinedWith: .gesture(.tapOutside))`
- macOS: `.sheet(isPresented: $showSettings, onDismiss: {})`

### 4. DND y Slack no se bloquean correctamente

**Problema:** El modo focus no está bloqueando correctamente las notificaciones en macOS ni actualizando el status en Slack.

**Efecto:** Eliab recibe notificaciones mientras debería estar en focus, o Slack no muestra el estado de "focus" a su equipo.

**Solución:**
- Revisar implementación de DND (Do Not Disturb) en macOS
- Verificar si está usando `ProcessInfo.processInfo.isUserActivityProcessing`
- Verificar permisos de Accessibility en System Settings
- Revisar integración con Slack API:
  - Verificar que el token sea válido
  - Verificar scope `users.profile:write`
  - Revisar llamadas a `slack.client.users.profile.set`
- Agregar logging detallado para debug
- Test manual en ambos casos (DND + Slack)

## Tareas de implementación

### Backend

- [ ] **Issue 1: Mostrar versión**
  - Agregar propiedad `Bundle.main.version` en Swift
  - Mostrar en menú: `Application > About Focally` o menú contextual

- [ ] **Issue 4: Debug DND/Slack**
  - Agregar logs de depuración
  - Verificar permisos (Accessibility)
  - Verificar integración Slack
  - Test manual exhaustivo

### Frontend (Views)

- [ ] **Issue 2: Selector de tarea**
  - Agregar `Picker` o `Menu` de tareas en panel principal
  - Guardar selección en UserDefaults
  - Pre-cargar en `OnItFocusApp.init()`

- [ ] **Issue 3: Cerrar modal**
  - Agregar `onDismiss` closure en sheet/modal
  - O usar `presentationDetents` con tapOutside
  - Test en both iOS and macOS

## Testing checklist

- [ ] Abrir app → Ver versión en menú
- [ ] Configurar 2+ tareas predeterminadas
- [ ] Iniciar sesión → Ver selector de tarea
- [ ] Elegir tarea → Iniciar sesión con esa tarea
- [ ] Abrir settings → Guardar cambios → Modal se cierra automáticamente
- [ ] Activar focus → Verificar DND se activa
- [ ] Activar focus → Verificar Slack status se actualiza
- [ ] Terminar focus → Verificar DND se desactiva
- [ ] Terminar focus → Verificar Slack status se limpia

## Acceptance criteria

- ✅ Eliab puede ver la versión de Focally sin salir de la app
- ✅ Eliab puede elegir una tarea predefinida al iniciar sesión
- ✅ El modal de settings se cierra automáticamente al guardar
- ✅ El modo focus activa DND correctamente en macOS
- ✅ El modo focus actualiza Slack status correctamente

## Dependencies

- **Memoria anterior:** No tiene
- **Skills:** `swift-lang`, `swiftui-core`

## Notas

- El Issue 4 es el más crítico — sin DND/Slack funcionando, la app no cumple su propósito principal
- Debe hacerse test manual exhaustivo después de implementar
- Considerar añadir "Report Bug" con versión pre-rellena al menú "About"
