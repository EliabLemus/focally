# Preguntas Aclaratorias para Bugs Reportados

**Fecha:** 2026-05-05
**Versión:** v0.6.4 (último release)
**Próxima versión:** v0.6.6 o v0.7.0 (pending)

---

## 📋 Lista de Bugs Reportados

### 1. Light Theme no funciona
**Reporte:** "Light Theme no funciona"
**Pregunta:** ¿Qué comportamiento esperas ver cuando seleccionas "Light" en Appearance settings?

**Investigación Inicial:**
- El código tiene `ThemeChoice.light` con `.preferredColorScheme = .light`
- `MainWindow.swift` aplica `.preferredColorScheme(selectedTheme.preferredColorScheme)`
- Pero la app parece ignorar esto o no actualizar

**Pregunta:** ¿Al seleccionar "Light", la app se queda en Dark mode o no cambia nada? ¿O cambia pero parcialmente (algunas vistas light, otras dark)?

---

### 2. Custom Session no se puede editar
**Reporte:** "Custom Session no la puedo editar por defecto esta en 45 minutos"
**Pregunta:** ¿Dónde y cómo quieres editar la duración de Custom Session?

**Investigación Inicial:**
- En `MenuBarDropdownView.swift` línea 88-92, el Custom Session Button usa `timerService.startWorkSession(..., durationMinutes: 45)` hardcodeado
- No hay TextField ni UI para cambiar los 45 minutos
- El botón simplemente inicia una sesión de 45 minutos fija

**Pregunta:** ¿Quieres que agregue un UI para editar la duración (ej. TextField o Stepper) antes de dar click en "Custom Session"? ¿O prefieres que el Custom Session abra una sheet con más opciones?

---

### 3. Slack Status
**Reporte:** "Aunque pone el estado en slack no veo que esté bloqueando las notificaciones"
**Pregunta:** ¿Qué significa "no veo que esté bloqueando las notificaciones"?

**Interpretación:** ¿Quieres decir que:
- A) El status de Slack NO se está actualizando (no ves el emoji/status en Slack)?
- B) Las notificaciones de macOS SI están llegando pero NO están bloqueando?
- C) Ambas cosas están fallando (Slack status NO se actualiza Y macOS notifications NO se bloquean)?

**Investigación Inicial:**
- `SlackService.setStatus(...)` actualiza el status en Slack
- `DNDService` controla las notificaciones de macOS (DO NOT DISTURB)
- Son dos servicios independientes
- Slack status NO bloquea notificaciones de macOS

**Pregunta:** ¿Quieres que:
- A) El status de Slack se actualice correctamente?
- B) Las notificaciones de macOS se bloqueen cuando inicia una sesión?
- C) Ambas cosas (Slack status + macOS DND)?

---

### 4. Settings Click no funciona
**Reporte:** "Al dar click en el icono del tiempo arriba a la derecha hay un engranage de settings que al darle click no funciona"
**Pregunta:** ¿Qué esperas que pase al dar click en el engranaje de settings?

**Investigación Inicial:**
- En `MenuBarDropdownView.swift` línea 54-56:
```swift
Button(action: {}) {  // ← ¡ACTION VACÍA!
    Image(systemName: "gearshape")
        ...
}
```
- El action del botón está VACÍO `{}` por eso no hace nada

**Pregunta:** ¿Quieres que el botón de settings:
- A) Abra la ventana principal de Focally en la pestaña "Settings"?
- B) Abra una sheet con opciones rápidas de settings?
- C) Alguna otra cosa específica?

---

### 5. About Focally - Versión Incorrecta
**Reporte:** "About Focally no coincide la version dice 0.6.4"
**Pregunta:** ¿Qué versión dice About Focally? ¿Es diferente de lo esperado?

**Investigación Inicial:**
- `project.yml` tiene `MARKETING_VERSION: "0.6.4"`
- `AboutSettingsView.swift` lee `Bundle.main.infoDictionary?["CFBundleShortVersionString"]`
- `Info.plist` usa `$(MARKETING_VERSION)` para `CFBundleShortVersionString`
- Debería mostrar "0.6.4"

**Pregunta:** ¿Qué versión ves en About Focally? ¿Es anterior a 0.6.4 (ej. 0.5.1 o 0.6.3)? ¿O dice algo más nuevo pero no debería?

---

### 6. Sound Notifications no funcionan
**Reporte:** "Sound notifications no funciona, probar"
**Pregunta:** ¿Qué comportamiento observas con los sonidos de notificación?

**Investigación Inicial:**
- `NotificationService.swift` usa `content.sound = .default` (línea 66)
- `GeneralSettingsView.swift` tiene opción para seleccionar sonido: "Crystal", "Breeze", "Minimal"
- Pero el servicio de notificaciones usa `.default` siempre, ignora la selección del usuario
- `.default` puede no estar funcionando o ser muy sutil

**Pregunta:** ¿Quieres decir que:
- A) Las notificaciones NO tienen sonido (son silenciosas)?
- B) Las notificaciones tienen sonido pero es el incorrecto (debe ser "Crystal" pero es otro)?
- C) Las notificaciones no llegan (ni sonido ni banner)?

---

### 7. Save Changes
**Reporte:** "Save Changes no se si está guardando o no los cambios"
**Pregunta:** ¿Dónde ves "Save Changes" y qué esperas que haga?

**Investigación Inicial:**
- `SettingsPage.swift` tiene un `Text("Save Changes")`
- Pero solo es un texto, NO hay botón ni acción asociada
- Los settings parecen usar `@AppStorage` que guarda automáticamente

**Pregunta:** ¿Quieres que:
- A) Elimines el texto "Save Changes" porque guarda automáticamente?
- B) Agregues un botón "Save Changes" que guarde manualmente?
- C) Agregues algún indicador visual de "Changes saved" / "Changes unsaved"?

---

### 8. Timer - Botones salen de pantalla
**Reporte:** "Timer se sale de la pantalla los botones stop/pause"
**Pregunta:** ¿Qué significa "se sale de la pantalla"? ¿Desaparecen? ¿O se cortan?

**Investigación Inicial:**
- `TimerControlsView.swift` tiene botones con frame `width: 64, height: 64`
- Los iconos tienen tamaño 28 puntos
- Esto parece pequeño pero no debería causar que desaparezcan

**Pregunta:** ¿Los botones:
- A) Desaparecen completamente de la vista?
- B) Se cortan por los bordes de la ventana/supervista?
- C) Se muestran mal (fuera de lugar, sobrepuestos con otros elementos)?

---

## 🎯 Estado Actual

| Bug | Investigación Inicial | Preguntas Pendientes |
|-----|----------------------|---------------------|
| 1. Light Theme | MainWindow aplica preferredColorScheme pero parece ignorarse | ¿Qué comportamiento esperas? |
| 2. Custom Session | Hardcoded 45 minutos, sin UI para editar | ¿Cómo editar duración? Sheet/TextField/Stepper? |
| 3. Slack Status | SlackService.setStatus existe, pero unclear qué falla | ¿Qué significa "no veo bloqueo"? ¿Slack status o DND? |
| 4. Settings Click | Button action está vacío `{}` | ¿Qué acción esperas? ¿Abrir Settings en MainWindow? |
| 5. About Version | Debería leer CFBundleShortVersionString de Info.plist | ¿Qué versión ves? ¿Incorrecta? |
| 6. Sound Notifications | NotificationService usa `.default`, ignora selección de usuario | ¿Sin sonido o sonido incorrecto? ¿Notificaciones llegan? |
| 7. Save Changes | Solo es texto, sin acción | ¿Eliminar texto o agregar botón/indicador? |
| 8. Timer Buttons | Frame 64x64, iconos de 28pt | ¿Desaparecen o se cortan? |

---

## ✅ Siguiente Paso

**Por favor responde a estas 8 preguntas aclaratorias antes de que empiece a hacer cambios.** Esto me permitirá:
1. Entender exactamente qué comportamiento esperas
2. Priorizar los bugs por impacto
3. Crear el plan de implementación correcto
4. Evitar cambios innecesarios o incorrectos

Gracias por el reporte detallado! 🙏
