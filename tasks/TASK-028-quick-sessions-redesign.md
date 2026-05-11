# TASK-028: Quick Sessions Redesign — Slack-Inspired Status

## Objetivo
Rediseñar la sección "Quick Sessions" del menú bar dropdown para que muestre el estado de calendario actual en un estilo similar al estado de Slack: badge de estado claro, compacto, y visualmente reconocible.

## Inspiración visual

### Patrón de Slack
- **Badge circular** con color de estado:
  - 🟢 Verde → Disponible
  - 🔴 Rojo → En meeting/ocupado
  - 🟡 Amarillo → Away
  - 🌙 L → En DND
- **Ícono contextual** (calendario, laptop, casa)
- **Texto principal** del estado
- **Subtítulo** opcional (source, tiempo restante)
- **Diseño compacto** de ~40px de altura
- **High contrast** para escaneo rápido

## Diseño propuesto

### Estructura

```
┌─────────────────────────────────────────┐
│  Quick session                         │
├─────────────────────────────────────────┤
│                                       │
│  ┌────────────────────────────────┐     │
│  │ 🟢  In a meeting            │     │
│  │     Google Calendar • 2:00 PM   │     │
│  └────────────────────────────────┘     │
│                                       │
│  ┌────────────────────────────────┐     │
│  │ 🌙  Free for next 30m       │     │
│  │     No conflicts until 3:30 PM  │     │
│  └────────────────────────────────┘     │
│                                       │
└─────────────────────────────────────────┘
```

### Estados posibles

| Estado | Badge color | Ícono | Texto principal | Subtítulo |
|--------|-------------|---------|-----------------|------------|
| En meeting | 🟢 Rojo (#FF3B30) | calendar | "In a meeting" | "Google Calendar • 2:00 PM" |
| Libre | 🟢 Verde (#36A64B) | checkmark.circle | "Free for focus" | "No conflicts until 3:30 PM" |
| Próximo evento | 🟡 Amarillo (#FFA000) | clock | "Up next" | "Team standup in 15m" |
| DND activo | 🌙 Púrpura (#8B5CF6) | moon.fill | "Quiet mode on" | "DND Active • 25m remaining" |
| Error | 🔴 Gris rojo (#DC2626) | exclamationmark.triangle | "Calendar disconnected" | "Check Settings" |

## Especificaciones técnicas

### Componentes nuevos

```swift
// CalendarStatusCard.swift
struct CalendarStatusCard: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusBadge
            statusDetails
        }
        .padding(16)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusBorderColor, lineWidth: 1)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

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
    }

    private var statusDetails: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)

            Text(statusDetail)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
    }

    // MARK: - Status Properties

    private var statusColor: Color {
        guard let meeting = calendarService.currentMeeting else {
            return Color.green // Free
        }

        let now = Date()
        if now >= meeting.startTime && now < meeting.endTime {
            return Color.red // In meeting
        }

        if now < meeting.startTime && meeting.startTime.timeIntervalSinceNow < 3600 {
            return Color.orange // Up soon (< 1h)
        }

        return Color.green
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

    private var statusBorderColor: Color {
        statusColor.opacity(0.3)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// QuickSessionsSection.swift
struct QuickSessionsSection: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var timerService: FocusTimerService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 10) {
                CalendarStatusCard()

                if !timerService.hasSession {
                    quickStartControls
                }
            }
        }
    }

    private var header: some View {
        Text("Quick sessions")
            .font(.focallyBodyBold)
            .foregroundStyle(Color.focallyOnSurface)
    }

    private var quickStartControls: some View {
        // Existing quick start UI here
        HStack(spacing: 10) {
            CompactStatusEmojiButton(selection: $selectedEmoji, options: FocusStatusOption.common)
            TextField("What are you focusing on?", text: $taskInput)
                .textFieldStyle(.roundedBorder)
        }
    }
}
```

## Integración con MenuBarDropdownView.swift

```swift
// En quickStartSection, reemplazar con:
private var quickStartSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        // NEW: Calendar status card (Slack-inspired)
        if calendarService.isEnabled && calendarService.isSignedIn {
            CalendarStatusCard()
        }

        // Existing quick start controls
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CompactStatusEmojiButton(selection: $selectedEmoji, options: FocusStatusOption.common)
                TextField("What are you focusing on?", text: $taskInput)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Slack status: \(selectedEmoji)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            DurationControl(minutes: $selectedDuration, range: 5...180, step: 5)
                .padding(.horizontal, 2)

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
        }
    }
    .padding(14)
    .background(Color.focallySurfaceContainerLowest.opacity(0.65))
    .clipShape(RoundedRectangle(cornerRadius: 14))
}
```

## Mejoras UX

### Micro-interacciones

1. **Hover effect** en la tarjeta:
   - Sombra suave (`shadow(radius: 4)`)
   - Border color más opaco en hover

2. **Transición suave** de estados:
   - Animate badge color con `.animation(.easeInOut, value: statusColor)`
   - Fade in/out de subtítulos

3. **Accesibilidad**:
   - `.accessibilityLabel("Status: \(statusTitle)")`
   - `.accessibilityHint("Shows current calendar status")`

### Responsive

- **Desktop (>920px)**: Tarjeta full-width con subtítulo
- **Compacto (<920px)**: Sin subtítulo, solo badge + título

## Patrones de diseño aplicados

### De `swiftui-core`:
- ✅ `@EnvironmentObject` para servicios
- ✅ `@Published` properties en `GoogleCalendarService`
- ✅ Proper color scheme handling

### De `taste-skill` (soft-skill):
- ✅ Premium spacing (padding: 16)
- ✅ Subtle borders (opacity 0.3)
- ✅ Monospaced time formatting
- ✅ High contrast badge colors

### De `macos-menubar`:
- ✅ Compact height (~40-50px por tarjeta)
- ✅ Rounded corners consistentes (14px)
- ✅ Overlay para borders suaves

## Archivos a modificar/crear

### Archivos nuevos:
- `Focally/Views/Calendar/CalendarStatusCard.swift`
- `Focally/Views/Calendar/QuickSessionsSection.swift`

### Archivos a modificar:
- `Focally/Views/MenuBar/MenuBarDropdownView.swift`
  - Importar `GoogleCalendarService` como environment object
  - Reemplazar `quickStartSection` con nueva implementación
  - Agregar lógica de detección de conflictos

### Tests:
- `FocallyTests/CalendarStatusCardTests.swift`
  - Test de colores de estado
  - Test de formatting de tiempo
  - Test de accesibilidad

## Criterios de aceptación

- [ ] Badge de estado visible con color correcto según contexto
- [ ] Texto "In a meeting" cuando hay evento actual
- [ ] Texto "Free for focus" cuando no hay conflictos
- [ ] Subtítulo con hora del evento (Google Calendar • 2:00 PM)
- [ ] Hover suave con sombra
- [ ] Transición animada entre estados
- [ ] Accesibilidad con labels apropiados
- [ ] Responsivo en compacto/desktop
- [ ] No breaking de existente `quickStartSection`

## Riesgos

1. **Conflicto con `quickStartSection` existente**:
   - Solución: Integrar `CalendarStatusCard` arriba de los controles existentes, no reemplazarlos completamente
   - Mantener compatibilidad con flujo actual

2. **Perfomance de actualización**:
   - `GoogleCalendarService.currentMeeting` es computed, puede ser costoso si hay muchos eventos
   - Solución: Cache con `@Published var cachedCurrentMeeting: CalendarEvent?`

3. **Diseño overflow**:
   - Si texto es muy largo ("Team standup and sync with external partners..."), puede romper layout
   - Solución: `.lineLimit(1)` con truncamiento inteligente

## Mitigaciones

1. **Caching inteligente**:
   ```swift
   // En GoogleCalendarService
   private var lastComputedMeeting: CalendarEvent?
   private var lastComputationTime: Date?

   var currentMeeting: CalendarEvent? {
       let now = Date()

       // Reutilizar cache si es < 5s atrás
       if let last = lastComputedMeeting,
          lastComputationTime != nil,
          now.timeIntervalSince(lastComputationTime!) < 5 {
           return last
       }

       let meeting = events.first { now >= $0.startTime && now < $0.endTime }
       lastComputedMeeting = meeting
       lastComputationTime = now
       return meeting
   }
   ```

2. **Truncamiento inteligente**:
   ```swift
   Text(meetingTitle)
       .font(.focallyBodyBold)
       .foregroundStyle(Color.focallyOnSurface)
       .lineLimit(1)
       .truncationMode(.middle)
       // "Team standup..." → "Team ... standup"
   ```

3. **Gradual rollout**:
   - Feature flag para habilitar nueva UI
   - Fallback a UI antigua si hay problemas
   - A/B testing con subset de usuarios

## Referencias visuales

### Slack status patterns:
- Badge siempre visible, incluso cuando no hay estado
- Color del badge es la señal primaria de estado
- Texto secundario usa color más suave (opacity 0.7)
- Iconos SF Symbols 13-14px, no más

### Focally design tokens:
- `Color.focallyPrimary` → Accent color para badge en DND
- `Color.focallySurfaceContainerLow` → Background de tarjeta
- `Color.focallyOnSurface` → Texto principal
- `Color.focallyOnSurfaceVariant` → Texto secundario

## Timeline estimada

- **Diseño visual**: 2-3 horas (review y refinamiento)
- **Implementación**: 4-6 horas (coding con tests)
- **Testing**: 2-3 horas (manual testing + edge cases)
- **Total**: 8-12 horas

## Dependencies

Nuevas dependencias mínimas (ya existen en el proyecto):
- ✅ SwiftUI (framework nativo)
- ✅ `GoogleCalendarService` (ya implementado)
- ✅ Design tokens de Focally (ya definidos)
- ✅ SF Symbols (framework nativo)
