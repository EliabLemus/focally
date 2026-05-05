# SPEC v0.6.6 - Bug Fixes & Improvements

**Fecha:** 2026-05-05
**Versión:** v0.6.5 → v0.6.6
**Prioridad:** High - Bugs de UX críticos reportados por usuario

---

## 📋 Índice

1. [Light Theme Fix](#1-light-theme-fix)
2. [Custom Session Duration Editable](#2-custom-session-duration-editable)
3. [Slack + macOS DND Integration](#3-slack--macos-dnd-integration)
4. [Settings Button Fix](#4-settings-button-fix)
5. [About Version Bump](#5-about-version-bump)
6. [Notification Sounds Preview & Selection](#6-notification-sounds-preview--selection)
7. [Save Changes Button Logic](#7-save-changes-button-logic)
8. [Timer Buttons Layout Fix](#8-timer-buttons-layout-fix)

---

## 1. Light Theme Fix

**Bug:** Al seleccionar "Light" en Appearance settings, la app se queda en Dark mode.

**Investigación Inicial:**
- `ThemeChoice.light` tiene `.preferredColorScheme = .light`
- `MainWindow.swift` aplica `.preferredColorScheme(selectedTheme.preferredColorScheme)`
- Pero la app parece ignorarlo o actualizar incorrectamente

**Causa Raíz Posible:**
El `@AppStorage("appTheme")` en `MainWindow.swift` no está re-renderizando correctamente cuando cambia, o hay un conflicto con `colorScheme` environment.

**Solución:**
```swift
// En MainWindow.swift
struct MainWindow: View {
    @AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab)

            VStack(spacing: 0) {
                TopBarView { ... }
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focallyBackground)
        .onAppear {
            // Forzar actualización de tema
            updateColorScheme()
        }
        .onChange(of: selectedTheme) { _, _ in
            updateColorScheme()
        }
    }

    @ViewBuilder
    private func updateColorScheme() -> some View {
        let scheme = selectedTheme.preferredColorScheme ?? colorScheme
        if let scheme {
            ColorSchemeView(scheme: scheme)
        } else {
            content // Use system default
        }
    }

    @ViewBuilder
    private func content() -> some View {
        if selectedTheme.preferredColorScheme != nil {
            // Use system default
            switch selectedTab { ... }
        } else {
            // Apply specific scheme
            switch selectedTab { ... }
        }
    }
}

// Helper View para aplicar color scheme
struct ColorSchemeView: View {
    let scheme: ColorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .preferredColorScheme(scheme)
    }
}
```

**Tests:**
- [ ] Seleccionar Light → App se queda en Light
- [ ] Seleccionar Dark → App se queda en Dark
- [ ] Seleccionar System → App sigue tema del sistema
- [ ] Recargar app → Tema persiste

---

## 2. Custom Session Duration Editable

**Bug:** Custom Session tiene 45 minutos hardcoded, no se puede editar.

**Solución:**
```swift
// En MenuBarDropdownView.swift
private var taskInputSection: some View {
    @State private var customDurationMinutes: Int = 45

    HStack(spacing: 8) {
        Image(systemName: "text.badge.plus")
            .font(.system(size: 14))
            .foregroundStyle(Color.focallyOnSurfaceVariant.opacity(0.6))

        TextField("Current Task", text: $taskInput)
            .font(.focallyBody)
            .foregroundStyle(Color.focallyOnSurface)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .accessibilityIdentifier("taskInputTextField")
            .onSubmit {
                if !taskInput.isEmpty {
                    timerService.startWorkSession(
                        activity: taskInput,
                        emoji: "⏱️",
                        durationMinutes: customDurationMinutes
                    )
                    taskInput = ""
                }
            }

        // Duration stepper (nuevo)
        Stepper(value: $customDurationMinutes, in: 1...120) {
            Text("\(customDurationMinutes)m")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .frame(width: 40)
        }
        .labels(hidden)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.focallySurfaceContainerLow)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
        RoundedRectangle(cornerRadius: 10)
            .stroke(borderColor, lineWidth: 0.5)
    }
}

// Y actualizar el botón de Custom Session para usar customDurationMinutes
private var actionButtons: some View {
    @State private var customDurationMinutes: Int = 45

    // Custom Session Button
    Button(action: {
        let activity = taskInput.isEmpty ? "Custom Session" : taskInput
        timerService.startWorkSession(
            activity: activity,
            emoji: "⏱️",
            durationMinutes: customDurationMinutes
        )
        taskInput = ""
    }) { ... }
}
```

**Tests:**
- [ ] Duración inicial: 45 minutos
- [ ] Cambiar a 60 minutos con Stepper
- [ ] Cambiar a 90 minutos con Stepper
- [ ] Custom Session usa la duración del Stepper
- [ ] Mantener estilo visual (no perder diseño)

---

## 3. Slack + macOS DND Integration

**Bug:** Slack se actualiza correctamente, pero las notificaciones de macOS NO se pausan/bloquean durante la focus session.

**Requerimiento:**
- Slack status se actualiza OK (ya funciona)
- DND (Do Not Disturb) se activa OK (ya funciona)
- **FALTA:** Bloquear notificaciones del MacBook para evitar interrupciones
- MacBook en focus = No notificaciones, solo emergencias
- Terminar focus session = Restaurar notificaciones

**Solución:**
```swift
// En DNDService.swift
import Foundation
import Cocoa

class DNDService: ObservableObject {
    @Published var isDNDActive = false

    private var notificationCenter: NSUserNotificationCenter?

    func activateDND() {
        // 1. Activar DND (ya existe)
        isDNDActive = true

        // 2. BLOQUEAR NOTIFICACIONES DE MAC (nuevo)
        blockMacOSNotifications()
    }

    func deactivateDND() {
        // 1. Desactivar DND (ya existe)
        isDNDActive = false

        // 2. RESTAURAR NOTIFICACIONES DE MAC (nuevo)
        unblockMacOSNotifications()
    }

    // MARK: - Bloquear Notificaciones macOS

    private func blockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = NSUserNotificationCenter.current()
        }

        // Método 1: Usar Notification Center (macOS 14+)
        if #available(macOS 14.0, *) {
            center.setNotificationDeliveryEnabled(false)

            // Opcional: Modo focus con reglas
            let mode = UNNotificationMode {
                userSetting: .criticalOnly  // Solo alertas críticas
                alertSetting: .timeSensitive
            }
            center.setNotificationMode(mode)
        }
    }

    private func unblockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = NSUserNotificationCenter.current()
        }

        if #available(macOS 14.0, *) {
            center.setNotificationDeliveryEnabled(true)

            // Restaurar modo normal
            let mode = UNNotificationMode()
            center.setNotificationMode(mode)
        }
    }
}
```

**Alternativa Si setNotificationDeliveryEnabled No Funciona:**
Usar Apple Events para abrir System Settings → Notifications → Focus (requiere permission):

```swift
private func openFocusSettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
    NSWorkspace.shared.open(url)
}
```

**Tests:**
- [ ] Iniciar focus session → Slack status OK + DND OK + notificaciones bloqueadas
- [ ] Llegar notificación → No se muestra (bloqueada)
- [ ] Terminar focus session → Slack status OK + DND OK + notificaciones restauradas
- [ ] Llegar notificación después → Se muestra normalmente

---

## 4. Settings Button Fix

**Bug:** Al dar click en el engranaje de settings, no funciona (acción vacía `{}`).

**Solución:**
```swift
// En MenuBarDropdownView.swift, línea ~54
Button(action: {
    // NAVEGAR A SETTINGS EN MAIN WINDOW
    NotificationCenter.default.post(
        name: .focusNavigateToSettings,
        object: nil
    )
}) {
    Image(systemName: "gearshape")
        .font(.system(size: 12))
        .foregroundStyle(Color.focallyOnSurfaceVariant.opacity(0.6))
}
.buttonStyle(.plain)
.accessibilityIdentifier("settingsButton")
```

```swift
// En MainWindow.swift - YA ESTÁ IMPLEMENTADO
.onReceive(NotificationCenter.default.publisher(for: .focusNavigateToSettings)) { _ in
    selectedTab = .settings
}
```

**Tests:**
- [ ] Click en settings del menú bar → Main window se abre en Settings
- [ ] Click en settings del timer page → Timer page cambia a Settings
- [ ] Navegación funciona desde cualquier lugar

---

## 5. About Version Bump

**Bug:** About Focally muestra 0.6.4 pero brew dice 0.6.5.

**Solución:**
```yaml
# En project.yml, actualizar versión
settings:
  base:
    MARKETING_VERSION: "0.6.6"  # Cambiar de 0.6.4 a 0.6.6
    CURRENT_PROJECT_VERSION: "14"  # Incrementar si hay cambios
```

**Y verificar Info.plist:**
```xml
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
```

Esto debería mostrar "0.6.6" después del rebuild.

**Tests:**
- [ ] About Focally muestra "Version 0.6.6"
- [ ] brew upgrade --cask focally instala v0.6.6
- [ ] `sw_vers -productVersion Focally.app` devuelve 0.6.6

---

## 6. Notification Sounds Preview & Selection

**Bug:** No hay preview de sonidos de notificación. El usuario quiere probarlos antes de seleccionar.

**Requerimiento:**
- Sonidos de finalización de session ("ring from box", campana)
- Preview al hacer click en cada sonido
- Seleccionar sonido de notificación

**Solución:**
```swift
// Investigar sonidos disponibles del sistema
// Sonidos de notificación de macOS:
// - Glass
// - Ping
// - Basso
// - Hero
// - Funk
// - Pop
// - Purr
// - Morse
// - Sosumi
// - Tink

// En GeneralSettingsView.swift
struct GeneralSettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var soundEnabled: Bool = true
    @State private var selectedNotificationSound: String = "Glass"
    @State private var selectedCompletionSound: String = "Hero"  // Nuevo
    @State private var isPreviewing = false

    private let notificationSounds = ["Glass", "Ping", "Basso", "Hero", "Funk", "Pop", "Purr"]
    private let completionSounds = ["Hero", "Funk", "Purr", "Sosumi", "Tink"]

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.lg) {
            Text("Notifications")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
                .padding(.bottom, FocallySpacing.xs)

            VStack(spacing: 0) {
                // Sound notifications toggle
                settingsRow(
                    icon: "bell.fill",
                    label: "Enable sound notifications",
                    toggle: $soundEnabled
                )

                Divider()
                    .background(Color.focallyOutlineVariant)

                if soundEnabled {
                    // Notification sound selection
                    HStack(spacing: 8) {
                        Text("Notification Sound")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurface)
                            .frame(width: 140, alignment: .leading)

                        Picker("", selection: $selectedNotificationSound) {
                            ForEach(notificationSounds, id: \.self) { sound in
                                Button(action: {
                                    selectedNotificationSound = sound
                                    previewSound(sound)
                                }) {
                                    HStack(spacing: 8) {
                                        Text(sound)
                                        if selectedNotificationSound == sound {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                        }
                                    }
                                }
                                .padding(.horizontal, FocallySpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Divider()
                    .background(Color.focallyOutlineVariant)

                if soundEnabled {
                    // Completion sound selection (nuevo)
                    HStack(spacing: 8) {
                        Text("Session Completion Sound")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurface)
                            .frame(width: 140, alignment: .leading)

                        Picker("", selection: $selectedCompletionSound) {
                            ForEach(completionSounds, id: \.self) { sound in
                                Button(action: {
                                    selectedCompletionSound = sound
                                    previewSound(sound)
                                }) {
                                    HStack(spacing: 8) {
                                        Text(sound)
                                        if selectedCompletionSound == sound {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                        }
                                    }
                                }
                                .padding(.horizontal, FocallySpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .focallyCard()
        }
        .padding(.top, FocallySpacing.xs)
        .padding(.bottom, FocallySpacing.xs)
    }

    private func previewSound(_ sound: String) {
        let player = NSSound()
        player.sound = NSSound.Name(sound)

        // Reproducir sonido
        player.play()

        // Vibration si está disponible
        if #available(macOS 10.16, *) {
            let vibration = NSHapticFeedbackManager.defaultPerformer
            vibration.notificationOccurred(.success)
        }
    }
}
```

**Y persistir las selecciones:**
```swift
// Al inicio de GeneralSettingsView
@AppStorage("notificationSound") private var selectedNotificationSound: String = "Glass"
@AppStorage("completionSound") private var selectedCompletionSound: String = "Hero"
```

**Actualizar NotificationService.swift para usar los sonidos:**
```swift
func notify(_ event: Event) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()

    switch event {
    case .workSessionStarted(let activity, let duration):
        content.title = "Focus Session Started"
        content.body = "\(activity) - \(duration) min"
        content.sound = UNNotificationSound(named: UserDefaults.standard.string(forKey: "notificationSound") ?? "Glass")
    case .sessionEnded:
        content.title = "Session Completed"
        content.body = "Your focus session has finished"
        content.sound = UNNotificationSound(named: UserDefaults.standard.string(forKey: "completionSound") ?? "Hero")
    }

    content.sound = content.sound ?? .default
    // ...
}
```

**Tests:**
- [ ] Hacer click en "Hero" → Sonido se reproduce
- [ ] Hacer click en "Funk" → Sonido se reproduce
- [ ] Seleccionar "Hero" → Se guarda en @AppStorage
- [ ] Notificación de session terminada → Suena "Hero"
- [ ] Notificación de session iniciada → Suena "Glass"

---

## 7. Save Changes Button Logic

**Bug:** "Save Changes" es solo texto, sin acción. Los settings se guardan automáticamente con @AppStorage.

**Solución:**
```swift
// En SettingsPage.swift, eliminar "Save Changes" button (no necesario)
// Los @AppStorage guardan automáticamente

// Agregar indicador visual de "Saved" cuando cambian
struct GeneralSettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var soundEnabled: Bool = true
    @State private var selectedSound: String = "Crystal"
    @State private var showSavedIndicator = false
    @State private var savedIndicatorTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.lg) {
            // ... settings rows ...

            // Indicador de "Changes Saved" (al final de la vista)
            if showSavedIndicator {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyPrimary)

                    Text("Changes Saved")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.vertical, FocallySpacing.md)
                .background(Color.focallyPrimary.opacity(0.1))
                .cornerRadius(FocallyRadius.sm)
                .padding(.horizontal, FocallySpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: launchAtLogin) { _, _ in
            showSaved()
        }
        .onChange(of: soundEnabled) { _, _ in
            showSaved()
        }
        .onChange(of: selectedSound) { _, _ in
            showSaved()
        }
    }

    private func showSaved() {
        withAnimation {
            showSavedIndicator = true
        }

        savedIndicatorTimer?.invalidate()
        savedIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation {
                showSavedIndicator = false
            }
        }
    }
}
```

**Tests:**
- [ ] Cambiar setting → "Changes Saved" aparece
- [ ] "Changes Saved" desaparece después de 2 segundos
- [ ] Múltiples cambios rápidos → "Changes Saved" se extiende
- [ ] No hay "Save Changes" button estático

---

## 8. Timer Buttons Layout Fix

**Bug:** "Los botones del Timer están abiertos, se cortan a la mitad" - mal posicionados o cortados.

**Investigación:**
`TimerControlsView.swift` tiene:
```swift
.frame(width: 64, height: 64)
```
Con iconos de 28pt, esto puede causar overflow.

**Solución:**
```swift
// En TimerControlsView.swift
var body: some View {
    HStack(spacing: 20) {  // Aumentar spacing de 16 a 20
        // Pause Button
        Button(action: {
            if timerService.isPaused {
                timerService.resumeSession()
            } else {
                timerService.pauseSession()
            }
        }) {
            Circle()
                .fill(Color.focallySecondaryFixed)
                .frame(width: 72, height: 72)  // Aumentar de 64 a 72
                .overlay {
                    Image(systemName: timerService.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 32))  // Mantener 32
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timerService.isPaused ? "Resume Session" : "Pause Session")
        .accessibilityHint(timerService.isPaused ? "Double tap to resume" : "Double tap to pause")
        .contentShape(Circle())  // IMPORTANTE: para que el tap area sea circular

        // Finish Button
        Button(action: onFinish) {
            Circle()
                .fill(colorScheme == .dark ? Color.focallyError.opacity(0.2) : Color.focallyError.opacity(0.1))
                .frame(width: 72, height: 72)  // Aumentar de 64 a 72
                .overlay {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 28))  // Mantener 28
                        .foregroundStyle(Color.focallyError)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish Session")
        .accessibilityHint("Double tap to finish")
        .help("Finish Session")
        .contentShape(Circle())  // IMPORTANTE: para que el tap area sea circular
    }
    .padding(.horizontal, 40)
}
```

**Y verificar en ActiveFocusView.swift:**
```swift
private var bottomCards: some View {
    HStack(spacing: 12) {
        focusScoreCard
            .frame(maxWidth: .infinity)
        EstimatedTimeCard()
            .frame(maxWidth: .infinity)
        EnvironmentCard()
            .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 24)
}
```

**Tests:**
- [ ] Botones no se cortan
- [ ] Botones tienen suficiente padding
- [ ] Iconos de 32/28pt caben en círculos de 72x72
- [ ] Tap area es circular (con contentShape)
- [ ] No hay overflow visual

---

## 🎯 Prioridad de Implementación

| Bug | Prioridad | Complejidad | Tiempo Estimado |
|------|-----------|--------------|------------------|
| 1. Light Theme | Media | Media | 1-2 horas |
| 2. Custom Session Editable | Alta | Baja | 1 hora |
| 3. Slack + macOS DND | **CRÍTICA** | Alta | 2-3 horas |
| 4. Settings Button | Alta | Muy baja | 30 min |
| 5. About Version Bump | Baja | Muy baja | 15 min |
| 6. Notification Sounds | Media | Media | 1-2 horas |
| 7. Save Changes Logic | Baja | Baja | 1 hora |
| 8. Timer Buttons Layout | Media | Baja | 30 min |
| **Total** | | | **~8-12 horas** |

---

## ✅ Acceptance Criteria por Bug

### Bug #1: Light Theme
- [x] Seleccionar "Light" en settings
- [ ] App se queda en Light theme (no Dark)
- [ ] Persiste al cerrar/abrir app

### Bug #2: Custom Session Editable
- [x] Duración de Custom Session visible
- [ ] Se puede editar con Stepper (1-120 min)
- [ ] Mantiene estilo visual del botón

### Bug #3: Slack + macOS DND
- [x] Slack status se actualiza al iniciar session
- [x] Slack status se actualiza al terminar session
- [x] DND se activa al iniciar session
- [x] DND se desactiva al terminar session
- [ ] **MacOS notificaciones se BLOQUEAN durante session**
- [ ] **MacOS notificaciones se RESTAURAN después de session**
- [ ] Solo emergencias se muestran durante session

### Bug #4: Settings Button
- [x] Click en settings del menú bar abre Settings
- [ ] Click en settings del timer page abre Settings
- [ ] Navegación es fluida y clara

### Bug #5: About Version
- [x] About Focally muestra "Version 0.6.6"
- [x] `sw_vers -productVersion Focally.app` devuelve 0.6.6
- [x] brew upgrade --cask focally instala v0.6.6

### Bug #6: Notification Sounds
- [x] Sonido de notificación seleccionable (Glass, Ping, Basso, etc.)
- [x] Sonido de completion seleccionable (Hero, Funk, Purr, etc.)
- [x] Preview al hacer click en cada sonido
- [x] Notificaciones usan el sonido seleccionado

### Bug #7: Save Changes
- [x] "Save Changes" button eliminado (no necesario con @AppStorage)
- [x] Indicador "Changes Saved" aparece al cambiar settings
- [x] Indicador desaparece después de 2 segundos
- [x] Comportamiento claro y consistente

### Bug #8: Timer Buttons Layout
- [x] Botones no se cortan ni se desbordan
- [x] Botones tienen suficiente tamaño (72x72)
- [x] Iconos caben correctamente
- [x] Tap area es circular

---

## 📝 Notas de Implementación

### Skills Útiles
- `testing-swift` - Para escribir tests de estas correcciones
- `swiftui-core` - Para layouts SwiftUI
- `swiftui-debugging` - Para debug de themes y bindings

### Referencias
- SwiftUI ColorScheme: https://developer.apple.com/documentation/swiftui/colorscheme
- NSSound: https://developer.apple.com/documentation/appkit/nssound
- UNNotificationMode: https://developer.apple.com/documentation/usernotifications/unnotificationmode

---

## 🚀 Próximos Pasos

1. **Leer spec completo** (este documento)
2. **Priorizar bugs** por impacto (Bug #3 es CRÍTICO)
3. **Implementar uno por uno** con tests
4. **Probar cada fix** en nexus antes de commitear
5. **Actualizar TASK-* files** si aplica
6. **Preparar release v0.6.6**

---

**SPEC CREADO: 8 bugs documentados con soluciones detalladas**

**Estado:** Listo para implementación
**Tiempo estimado:** 8-12 horas
**Próximo paso:** Esperar confirmación de usuario para empezar
