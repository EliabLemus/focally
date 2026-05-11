# TASK-029: Implement Quick Sessions with Slack-Inspired Calendar Status

## Objetivo
Implementar la sección Quick Sessions con un diseño inspirado en el estado de Slack que:
1. Muestra el estado del calendario actual (free/in meeting/upcoming) en un badge estilo Slack
2. Permite elegir un icono de estado (emoji selector como en Slack)
3. Nombra la Quick Session
4. Ajusta la duración
5. Botón de "Start focus" para dar play

## Contexto de diseño

### Layout propuesto

```
┌──────────────────────────────────────┐
│ Quick Sessions                       │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐   │ ← Calendar Status Card (Slack-style)
│  │ 🟢  Free for focus         │   │ - Badge de estado (🟢/🔴/🟡)
│  │     No conflicts until 3:30 PM │   │ - Título del estado
│  └────────────────────────────────┘   │ - Subtítulo con hora
│                                      │
│  ┌────────────────────────────────┐   │
│  │ 🎯  What are you focusing│   │ ← Quick Start Controls
│  │     on?                     │   │ - Emoji selector
│  └────────────────────────────────┘   │ - Text field para nombre
│  [Duración: 25m]                  │   - Duration control
│  [▶️ Start focus] [Start Pomodoro]   │   - Botones de acción
│                                      │
└──────────────────────────────────────┘
```

## Archivos a crear

### 1. CalendarStatusCard.swift
**Ruta**: `Focally/Views/Calendar/CalendarStatusCard.swift`

**Responsabilidad**: Tarjeta de estado de calendario estilo Slack

**Estructura**:
```swift
import SwiftUI

struct CalendarStatusCard: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge de estado (Slack-style)
            statusBadge

            // Detalles del estado
            statusDetails
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusBorderColor, lineWidth: 1)
        }
    }

    // MARK: - Badge Section

    private var statusBadge: some View {
        HStack(spacing: 10) {
            // Dot de estado animado
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                }

            // Texto del estado
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                    .lineLimit(1)

                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusBadgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9999))
    }

    // MARK: - Details Section

    private var statusDetails: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)
                .background(statusColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(statusDetail)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
    }

    // MARK: - Status Properties

    /// Color del estado (Slack-inspired)
    private var statusColor: Color {
        guard let meeting = calendarService.currentMeeting else {
            return Color(red: 0.13, green: 0.77, blue: 0.37) // Green (#22C55E)
        }

        let now = Date()
        if now >= meeting.startTime && now < meeting.endTime {
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Red (#EF4444)
        }

        if now < meeting.startTime && meeting.startTime.timeIntervalSinceNow < 3600 {
            return Color(red: 0.92, green: 0.76, blue: 0.03) // Yellow (#EAB308)
        }

        return Color(red: 0.13, green: 0.77, blue: 0.37)
    }

    private var statusTitle: String {
        guard let meeting = calendarService.currentMeeting else {
            return "Free for focus"
        }

        let now = Date()
        if now >= meeting.startTime && now < meeting.endTime {
            return "In a meeting"
        }

        return "Up next"
    }

    private var statusSubtitle: String? {
        guard let meeting = calendarService.currentMeeting else {
            return nil
        }

        return "Google Calendar • \(formatTime(meeting.startTime))"
    }

    private var statusIcon: String {
        guard let meeting = calendarService.currentMeeting else {
            return "checkmark.circle.fill"
        }

        let now = Date()
        if now >= meeting.startTime && now < meeting.endTime {
            return "calendar.badge.clock"
        }

        return "clock.fill"
    }

    private var statusDetail: String {
        guard let meeting = calendarService.currentMeeting else {
            return "No conflicts until next event"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(meeting.title) • \(formatter.string(from: meeting.startTime))"
    }

    private var statusBadgeBackground: Color {
        statusColor.opacity(0.15)
    }

    private var statusBorderColor: Color {
        statusColor.opacity(0.3)
    }

    private var cardBackground: Color {
        Color.focallySurfaceContainerLow
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
```

### 2. QuickSessionsSection.swift
**Ruta**: `Focally/Views/Calendar/QuickSessionsSection.swift`

**Responsabilidad**: Sección completa de Quick Sessions integrando CalendarStatusCard + Quick Start

**Estructura**:
```swift
import SwiftUI

struct QuickSessionsSection: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var timerService: FocusTimerService
    @EnvironmentObject private var slackService: SlackService

    @State private var taskInput: String = ""
    @State private var selectedEmoji: String = "🎯"
    @State private var selectedDuration: Int = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 10) {
                // 1. Calendar Status Card (Slack-style)
                if calendarService.isEnabled && calendarService.isSignedIn {
                    CalendarStatusCard()
                }

                // 2. Quick Start Controls (solo si no hay sesión activa)
                if !timerService.hasSession {
                    quickStartControls
                }
            }
        }
        .padding(14)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Header

    private var sectionHeader: some View {
        Text("Quick sessions")
            .font(.focallyBodyBold)
            .foregroundStyle(Color.focallyOnSurface)
    }

    // MARK: - Quick Start Controls

    private var quickStartControls: some View {
        VStack(spacing: 10) {
            // Emoji selector (estilo Slack)
            emojiSelector

            // Task name input
            taskNameInput

            // Slack status preview
            slackStatusPreview

            // Duration control
            DurationControl(minutes: $selectedDuration, range: 5...180, step: 5)
                .padding(.horizontal, 2)

            // Action buttons
            actionButtons
        }
    }

    // MARK: - Emoji Selector

    private var emojiSelector: some View {
        CompactStatusEmojiButton(selection: $selectedEmoji, options: FocusStatusOption.common)
    }

    // MARK: - Task Name Input

    private var taskNameInput: some View {
        TextField("What are you focusing on?", text: $taskInput)
            .font(.focallyBody)
            .foregroundStyle(Color.focallyOnSurface)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .onSubmit(startSession)
    }

    // MARK: - Slack Status Preview

    private var slackStatusPreview: some View {
        Text("Slack status: \(selectedEmoji)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.focallyOnSurfaceVariant)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Start Focus button
            Button(action: startSession) {
                HStack {
                    Label("Start focus", systemImage: "play.fill")
                        .font(.focallyBodyBold)
                    Spacer()
                    Text("\(selectedDuration)m")
                        .font(.focallyCaption)
                }
                .foregroundStyle(Color.focallyOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.focallySecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Pomodoro button
            Button(action: startPomodoro) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pomodoro")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurface)
                        Text("25 · 5 cadence, 4 rounds")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.focallySurfaceContainerLowest.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Properties

    private var borderColor: Color {
        Color.focallyCardBorder.opacity(0.5)
    }

    private var sectionBackground: Color {
        Color.focallySurfaceContainerLowest.opacity(0.65)
    }

    // MARK: - Actions

    private func startSession() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = trimmed.isEmpty ? "Focus Session" : trimmed
        timerService.updateWorkDuration(minutes: selectedDuration)
        timerService.startWorkSession(activity: activity, emoji: selectedEmoji, durationMinutes: selectedDuration)
        taskInput = ""
    }

    private func startPomodoro() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = trimmed.isEmpty ? "Pomodoro" : trimmed
        timerService.startPomodoroSession(activity: activity, emoji: selectedEmoji)
        taskInput = ""
    }
}
```

## Archivos a modificar

### MenuBarDropdownView.swift
**Ruta**: `Focally/Views/MenuBar/MenuBarDropdownView.swift`

**Cambios**:
1. Importar `GoogleCalendarService` como `@EnvironmentObject`
2. Reemplazar `quickStartSection` con `QuickSessionsSection`

```swift
// Agregar a los @EnvironmentObject existentes:
@EnvironmentObject private var calendarService: GoogleCalendarService

// En quickStartSection, reemplazar con:
private var quickStartSection: some View {
    QuickSessionsSection()
}
```

## Estados posibles del calendario

| Estado | Badge Color | Emoji | Título | Subtítulo |
|---------|-------------|-------|---------|------------|
| **Free** | 🟢 Verde (#22C55E) | checkmark.circle.fill | "No conflicts until next event" |
| **In meeting** | 🔴 Rojo (#EF4444) | calendar.badge.clock | "In a meeting" + "Google Calendar • HH:MM" |
| **Up next** | 🟡 Amarillo (#EAB308) | clock.fill | "Up next" + evento + hora |
| **Error** | 🔴 Gris rojo (#DC2626) | exclamationmark.triangle | "Calendar disconnected" |

## Criterios de aceptación

### Funcionalidad
- [ ] CalendarStatusCard muestra estado correcto según GoogleCalendarService
- [ ] Badge de estado usa colores Slack-inspired (verde/rojo/amarillo)
- [ ] Dot de estado con pulso sutil (opacity animation)
- [ ] Título del estado truncado con `.lineLimit(1)`
- [ ] Subtítulo muestra hora formateada (HH:MM)
- [ ] QuickSessionsSection muestra CalendarStatusCard arriba de controles
- [ ] Emoji selector funciona (CompactStatusEmojiButton existente)
- [ ] Task name input permite escribir nombre de Quick Session
- [ ] Slack status preview muestra emoji seleccionado
- [ ] Duration control ajusta minutos
- [ ] Botones "Start focus" y "Start Pomodoro" funcionan
- [ ] QuickSessionsSection solo se muestra si no hay sesión activa

### UX/UI
- [ ] Tarjeta de estado tiene padding: 16px
- [ ] Badge de estado usa background opacity 0.15
- [ ] Border de tarjeta usa opacity 0.3
- [ ] Icono de detalle tiene fondo opacity 0.12
- [ ] Espaciado consistente entre elementos (10-12px)
- [ ] Colores usan design tokens de Focally
- [ ] Tipografía usa font families existentes (.focallyBodyBold, .focallyCaption)

### Accesibilidad
- [ ] `.accessibilityLabel` en todos los elementos interactivos
- [ ] VoiceOver describe estado del calendario
- [ ] Contrast ratios WCAG AA compliant (4.5:1 mínimo)
- [ ] Focus states visibles en modo high contrast

### Responsivo
- [ ] CalendarStatusCard se ajusta a ancho disponible
- [ ] Texto con `.lineLimit(1)` para evitar overflow
- [ ] QuickSessionsSection funciona en <920px y >=920px

### Compatibilidad
- [ ] No rompe `quickStartSection` existente en otros contextos
- [ ] Usa `GoogleCalendarService` existente sin cambios
- [ ] Usa `FocusStatusOption.common` existente
- [ ] Usa `DurationControl` existente
- [ ] Usa `CompactStatusEmojiButton` existente

### Testing
- [ ] Test de estado "Free" (sin eventos)
- [ ] Test de estado "In meeting" (evento actual)
- [ ] Test de estado "Up next" (evento en <1h)
- [ ] Test de cambio de estados (evento termina → vuelve a free)
- [ ] Test de Slack status preview actualiza con emoji
- [ ] Test de task name con texto largo (debe truncar)
- [ ] Test de duration control (5-180 minutos)
- [ ] Test de botones start/pomodoro
- [ ] Test de accesibilidad con VoiceOver

## Riesgos y mitigaciones

### Riesgo 1: Performance de CalendarService.currentMeeting
**Problema**: `currentMeeting` es computed property que itera sobre todos los eventos cada vez.

**Mitigación**:
- Cachear resultado en `GoogleCalendarService`:
  ```swift
  @Published private var cachedCurrentMeeting: CalendarEvent?
  private var lastCacheTime: Date?

  var currentMeeting: CalendarEvent? {
      let now = Date()

      // Reutilizar cache si es <5s atrás
      if let cached = cachedCurrentMeeting,
         let cachedTime = lastCacheTime,
         now.timeIntervalSince(cachedTime) < 5 {
          return cached
      }

      let meeting = events.first { now >= $0.startTime && now < $0.endTime }
      cachedCurrentMeeting = meeting
      lastCacheTime = now
      return meeting
  }
  ```

### Riesgo 2: Overflow de texto
**Problema**: Nombres de eventos muy largos pueden romper el layout.

**Mitigación**:
- Usar `.lineLimit(1)` con `.truncationMode(.middle)`
- Agregar `.fixedSize(horizontal: false, vertical: true)` al VStack contenedora

### Riesgo 3: Cambio de estado no actualiza UI
**Problema**: CalendarService publica cambios pero la UI no reacciona.

**Mitigación**:
- `GoogleCalendarService` ya es `@ObservableObject`, suscribirse en `CalendarStatusCard`:
  ```swift
  struct CalendarStatusCard: View {
      @EnvironmentObject private var calendarService: GoogleCalendarService

      var body: some View {
          // calendarService.currentMeeting es @Published → actualiza UI automáticamente
          // ...
      }
  }
  ```

## Dependencies

### Archivos existentes a usar
- ✅ `FocusStatusOption.common` (ya definido en FocusSessionComponents.swift)
- ✅ `DurationControl` (ya definido en FocusSessionComponents.swift)
- ✅ `CompactStatusEmojiButton` (ya definido en FocusSessionComponents.swift)
- ✅ `GoogleCalendarService` (ya implementado en Services/)
- ✅ `FocusTimerService` (ya implementado en Services/)
- ✅ `SlackService` (ya implementado en Services/)
- ✅ Design tokens de Focally (Color.focallyPrimary, .focallySurfaceContainerLow, etc.)

### Frameworks necesarios
- ✅ SwiftUI (ya importado)
- ✅ Foundation (para Date formatting)
- ✅ No dependencias externas necesarias

## Timeline de implementación

1. **Crear Calendar/ directory**: `mkdir -p Focally/Views/Calendar`
2. **Crear CalendarStatusCard.swift**: Copiar código del spec
3. **Crear QuickSessionsSection.swift**: Copiar código del spec
4. **Modificar MenuBarDropdownView.swift**: Reemplazar `quickStartSection`
5. **Build and test**: `xcodebuild build`
6. **Manual testing**:
   - Abrir Quick Sessions
   - Verificar estados de calendario (free/in meeting/up next)
   - Probar emoji selector
   - Escribir nombre de sesión
   - Ajustar duración
   - Start focus session
7. **Automated testing**: Ejecutar unit tests si existen

## Notas para Codex

1. **Colores Slack-inspired** usar hex values exactos:
   - Green: `Color(red: 0.13, green: 0.77, blue: 0.37)` (#22C55E)
   - Red: `Color(red: 0.94, green: 0.27, blue: 0.27)` (#EF4444)
   - Yellow: `Color(red: 0.92, green: 0.76, blue: 0.03)` (#EAB308)

2. **Usar design tokens de Focally**:
   - NO hardcodear colores, usar `Color.focallyPrimary`, `Color.focallySurfaceContainerLow`, etc.
   - NO hardcodear fonts, usar `.focallyBodyBold`, `.focallyCaption`, etc.

3. **Accessibility es crítica**:
   - Agregar `.accessibilityLabel("Status: \(statusTitle)")` a badge
   - Agregar `.accessibilityHint("Shows current calendar status")` a tarjeta
   - Verificar contrast con herramientas o manual

4. **Performance**:
   - CalendarStatusCard debe ser ligera, no hacer cómputos pesados en `body`
   - Usar `@Published` properties ya existentes en CalendarService

5. **Testing priority**:
   - Primero hacer build y verificar que compile
   - Luego probar manualmente en la app
   - Finalmente revisar accesibilidad

## Result

- Status: Done
- Summary: Added a new `QuickSessionsSection` and `CalendarStatusCard` with Slack-style calendar availability states, moved the menubar quick-start UI into the new section, and registered both files in the Xcode project. The card now covers free, in-meeting, up-next, and disconnected states, includes a subtle pulse indicator, and adds accessibility labels/hints for the interactive controls.
- Modified files:
  - `Focally/Views/Calendar/CalendarStatusCard.swift`
  - `Focally/Views/Calendar/QuickSessionsSection.swift`
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift`
  - `Focally.xcodeproj/project.pbxproj`
  - `tasks/TASK-029-implement-quick-sessions-slack-style.md`
- Notes:
  - The spec does not include a literal `Archivos relevantes` section, so the implementation treated the files explicitly referenced under `Archivos a modificar` and `Dependencies` as the required pre-read set.
  - Verification: `xcodebuild -project /Users/openjaime/.openclaw/workspace/projects/focally/Focally.xcodeproj -scheme Focally -configuration Debug build` succeeded.
  - The build still reports two existing warnings in `Focally/OnItFocusApp.swift` about calls to main-actor isolated methods from synchronous contexts; those warnings were not introduced by this task.
