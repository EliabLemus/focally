# Parche Focally Calendar & Slack + Custom Focus Types v0.9.4

## Resumen
1. Implementar canal de calendario INDEPENDIENTE de focus modes
2. Focus types personalizables por el usuario (crear/editar/eliminar)
3. Agregación de métricas para focus types personalizados

## Arquitectura de prioridades (canales)

**Orden de prioridad (solo uno activo a la vez):**
1. **Focus mode activo** → Usa settings del focus mode (comportamiento actual)
2. **Evento de calendario activo** (sin focus mode) → Usa settings de calendario
3. **Nada activo** → Estado idle (comportamiento actual)

**Never simultáneo:** No se mezclan focus mode + calendario.

## Parte 1: Canal de calendario independiente

### 1.1 Logica en FocusIntegrationService

```
func determineActiveChannel() -> Channel {
    if activeFocusMode != nil {
        return .focusMode
    }
    if activeCalendarEvent != nil && calendarSettings.showCalendarInSlack {
        return .calendar
    }
    return .idle
}
```

**Canal calendar:**
- Solo se activa cuando NO hay focus mode activo
- Solo si `calendarSettings.showCalendarInSlack = true`
- Muestra info del evento de calendario activo en Slack

### 1.2 Detección de video calls + métricas

**Nuevo servicio CalendarEventAnalyzer:**
- `analyzeMeetingType(event)`: Detecta tipo de reunión
- `isVideoCall(event)`: Boolean si es video call

**Criterios de detección (prioridad):**
1. EventKit location contiene URL de video call
2. EventKit URL property
3. Keywords en título: meet, zoom, call, video, teams

**Tracking de métricas:**
- Cuando un evento de video call del calendario esté activo (canal calendar)
- Llamar a `FocusMetricsService.shared.recordSession()` con:
  - `modeType = .calendarVideoCall` (nuevo tipo built-in)
  - `modeID = UUID()` (ID aleatorio para calendar events)
  - `startTime = event.startDate`
  - `endTime = event.endDate`
  - `duration = event.duration`
  - `pomodorosCompleted = nil`
- No contabilizar si está en focus mode (priority 1 ignora calendario)

### 1.3 Emojis del evento de calendario

**Nuevo servicio EmojiExtractor:**
- `extractAllEmojis(from: String) -> [String]`
- `concatenate(emojis: [String]) -> String`

**Logica:**
- Parsear texto buscando emojis Unicode
- Mantener orden de aparición
- NO extraer emojis de Discord (`:emoji:`) - solo Unicode

**Comportamiento:**
- Evento "🏖️ Vacation week 🏡" → emojis "🏖️🏡"
- Evento "Out of office" → vacio (sin emoji)
- Evento "Quick sync 🚀" → emoji "🚀"

### 1.4 Configuración global de calendario

**Nueva sección en Slack Settings:**
```
🔗 Integración Slack
├─ Estado (existente)
├─ DND (existente)
└─ Calendario (nuevo)
   ├─ ☐ Mostrar eventos de calendario
   │  (cuando no hay focus mode activo)
   ├─ Mostrar titulo:
   │  ○ Titulo completo
   │  ○ Solo "En video llamada"
   │  ○ No mostrar titulo
   ├─ ☐ Usar emojis del evento
   │  (reemplaza emoji por defecto)
   └─ ☐ Activar DND para video calls
```

**Nuevo modelo SlackCalendarSettings:**
```swift
struct SlackCalendarSettings: Codable {
    var showCalendarInSlack: Bool = false
    var titleDisplay: CalendarTitleDisplay = .hideTitle
    var useEventEmojisForStatus: Bool = false
    var activateDNDForVideoCalls: Bool = false
}

enum CalendarTitleDisplay: String, Codable {
    case showFullTitle
    case showVideoCallOnly
    case hideTitle
}
```

### 1.5 Casos de uso calendario

**Caso 1: Out of office**
```
Evento: "🏖️ Vacation week - No meetings"
Configuración: showCalendarInSlack = true, titleDisplay = .showFullTitle
Resultado Slack: Emoji "🏖️", Status "Vacation week - No meetings"
```

**Caso 2: Video call sin focus mode**
```
Evento: "Team standup" (zoom link)
Configuración: showCalendarInSlack = true, activateDNDForVideoCalls = true
Resultado: DND activado, metrics service registrando tiempo
```

**Caso 3: Focus mode activo (ignora calendario)**
```
Focus mode: "Deep work" activo
Evento: "Team meeting" simultaneo
Resultado: Usa settings de focus mode, IGNORA calendario
```

**Caso 4: Nada activo**
```
Sin focus mode, sin evento de calendario (o showCalendarInSlack = false)
Resultado: Estado idle actual
```

## Parte 2: Focus types personalizables

### 2.1 Arquitectura híbrida

**Modelo FocusType (personalizable):**
```swift
struct FocusType: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var color: String  // Hex color (ej: "#FF5733")

    init(name: String, emoji: String, color: String) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.color = color
    }
}
```

**Enum FocusModeType (built-in, estático):**
```swift
enum FocusModeType: String, Codable {
    case focusTime = "focus_time"
    case meeting = "meeting"
    case inbox = "inbox"
    case custom = "custom"
    case calendarVideoCall = "calendar_video_call"
    case userCustom  // Para tipos personalizados por el usuario

    var localizedLabel: String {
        switch self {
        case .focusTime: return "focus_mode_type_focus_time"
        case .meeting: return "focus_mode_type_meeting"
        case .inbox: return "focus_mode_type_inbox"
        case .custom: return "focus_mode_type_custom"
        case .calendarVideoCall: return "focus_mode_type_calendar_video_call"
        case .userCustom: return "focus_mode_type_user_custom"
        }
    }
}
```

**Descriptor unificado FocusTypeDescriptor:**
```swift
enum FocusTypeDescriptor: Equatable, Codable {
    case builtIn(FocusModeType)
    case custom(FocusType)

    var id: UUID {
        switch self {
        case .builtIn(let type):
            return UUID(uuidString: type.rawValue) ?? UUID()
        case .custom(let type):
            return type.id
        }
    }

    var name: String {
        switch self {
        case .builtIn(let type):
            return AppLanguage.localizedString(type.localizedLabel)
        case .custom(let type):
            return type.name
        }
    }

    var emoji: String {
        switch self {
        case .builtIn:
            return ""  // Built-in types don't have emojis
        case .custom(let type):
            return type.emoji
        }
    }

    var modeType: FocusModeType {
        switch self {
        case .builtIn(let type):
            return type
        case .custom:
            return .userCustom
        }
    }
}
```

### 2.2 Servicio FocusTypesService

**Nuevo servicio para gestionar tipos personalizados:**
```swift
@MainActor
@Observable
final class FocusTypesService {
    static let shared = FocusTypesService()

    private static let customTypesKey = "focally.focusTypes.custom"
    private(set) var customTypes: [FocusType] = []

    private init() {
        loadCustomTypes()
    }

    // MARK: - CRUD

    func addCustomType(_ type: FocusType) {
        customTypes.append(type)
        saveCustomTypes()
    }

    func updateCustomType(_ type: FocusType) {
        if let index = customTypes.firstIndex(where: { $0.id == type.id }) {
            customTypes[index] = type
            saveCustomTypes()
        }
    }

    func deleteCustomType(id: UUID) {
        customTypes.removeAll { $0.id == id }
        saveCustomTypes()
    }

    // MARK: - Query

    func getAllDescriptors() -> [FocusTypeDescriptor] {
        var descriptors: [FocusTypeDescriptor] = []

        // Built-in types
        for type in FocusModeType.allCases where type != .userCustom {
            descriptors.append(.builtIn(type))
        }

        // Custom types
        for type in customTypes {
            descriptors.append(.custom(type))
        }

        return descriptors
    }

    func findDescriptor(id: UUID) -> FocusTypeDescriptor? {
        // Check built-in types
        for type in FocusModeType.allCases {
            if UUID(uuidString: type.rawValue) == id {
                return .builtIn(type)
            }
        }

        // Check custom types
        for type in customTypes {
            if type.id == id {
                return .custom(type)
            }
        }

        return nil
    }

    // MARK: - Persistence

    private func loadCustomTypes() {
        guard let data = UserDefaults.standard.data(forKey: Self.customTypesKey) else {
            return
        }
        customTypes = (try? JSONDecoder().decode([FocusType].self, from: data)) ?? []
    }

    private func saveCustomTypes() {
        guard let data = try? JSONEncoder().encode(customTypes) else { return }
        UserDefaults.standard.set(data, forKey: Self.customTypesKey)
    }
}
```

### 2.3 Actualización de FocusMode

**Nuevo campo en FocusMode:**
```swift
struct FocusMode: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String
    var statusText: String
    var durationMinutes: Int
    var enableMacOSDND: Bool
    var enableSlackDND: Bool
    var enablePomodoro: Bool
    var pomodoroWorkMinutes: Int
    var pomodoroBreakMinutes: Int
    var pomodoroLongBreakMinutes: Int
    var pomodoroRounds: Int
    var breakLabel: String?

    // NUEVO: Type descriptor (reemplaza 'type')
    var typeDescriptor: FocusTypeDescriptor

    // Legacy field para backward compatibility
    var type: FocusModeType {
        get {
            return typeDescriptor.modeType
        }
        set {
            typeDescriptor = .builtIn(newValue)
        }
    }
}
```

### 2.4 UI: FocusModeEditorSheet

**Nueva sección Type:**
```swift
Section(header: Text("Type")) {
    Picker("Focus type", selection: $editMode.typeDescriptor) {
        ForEach(FocusTypesService.shared.getAllDescriptors(), id: \.id) { descriptor in
            HStack {
                Text(descriptor.emoji).font(.title)
                Text(descriptor.name)
            }
            .tag(descriptor)
        }
    }

    Button(action: { showAddTypeSheet = true }) {
        Label("Add new type", systemImage: "plus")
    }
}
.sheet(isPresented: $showAddTypeSheet) {
    AddFocusTypeSheet()
}
```

### 2.5 UI: AddFocusTypeSheet

**Nueva vista para agregar tipos personalizados:**
```swift
struct AddFocusTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @State private var color = "#FF5733"

    var body: some View {
        Form {
            Section(header: Text("New Focus Type")) {
                TextField("Name", text: $name)
                TextField("Emoji", text: $emoji)
                ColorPicker("Color", selection: Binding(
                    get: { Color(hex: color) ?? .blue },
                    set: { color = $0.toHex() }
                ))
            }

            Section {
                Button("Create") {
                    let newType = FocusType(name: name, emoji: emoji, color: color)
                    FocusTypesService.shared.addCustomType(newType)
                    dismiss()
                }
                .disabled(name.isEmpty || emoji.isEmpty)
            }
        }
    }
}
```

### 2.6 UI: FocusTypesSettingsView

**Nueva vista para gestionar tipos:**
```
Settings → Focus Types

┌─────────────────────────────────────┐
│ Focus Types                         │
├─────────────────────────────────────┤
│ Built-in                            │
│ ○ Focus Time                        │
│ ○ Meeting                           │
│ ○ Inbox                             │
│ ○ Custom                            │
├─────────────────────────────────────┤
│ My Types                            │
│ 🍕 Lunch                       [Edit][Delete]│
│ 🚗 Commute                     [Edit][Delete]│
│ 💪 Exercise                    [Edit][Delete]│
│ ☕ Coffee Break                [Edit][Delete]│
├─────────────────────────────────────┤
│ [+ Add new type]                    │
└─────────────────────────────────────┘
```

## Parte 3: Métricas con tipos personalizados

### 3.1 Actualización de DailyMetrics

**Nuevo modelo con duraciones dinámicas:**
```swift
struct DailyMetrics: Codable, Equatable {
    let date: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval

    // Duraciones por built-in type (para backward compatibility)
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval

    // Duraciones por custom type (diccionario dinámico)
    let customTypeDurations: [UUID: TimeInterval]  // typeID -> duration

    // Duración para calendar video calls
    let calendarVideoCallDuration: TimeInterval

    var meetingTimeFormatted: String {
        Self.formatDuration(meetingTime)
    }

    var totalFocusTimeFormatted: String {
        Self.formatDuration(totalFocusTime)
    }

    // Helpers para custom types
    func durationForType(_ descriptor: FocusTypeDescriptor) -> TimeInterval {
        switch descriptor {
        case .builtIn(let type):
            switch type {
            case .focusTime: return focusTimeDuration
            case .meeting: return meetingDuration
            case .inbox: return inboxDuration
            case .custom: return customDuration
            case .calendarVideoCall: return calendarVideoCallDuration
            case .userCustom: return 0
            }
        case .custom(let type):
            return customTypeDurations[type.id, default: 0]
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

### 3.2 Actualización de WeeklyMetrics/MonthlyMetrics

**Misma estructura que DailyMetrics:**
- Agregar `customTypeDurations: [UUID: TimeInterval]`
- Agregar `calendarVideoCallDuration: TimeInterval`
- Agregar helper `durationForType(_ descriptor:)`

### 3.3 Actualización de FocusMetricsService

**Modificación en `modeTypeBreakdown`:**
```swift
private func modeTypeBreakdown(for records: [FocusSessionRecord]) -> (
    focusTimeDuration: TimeInterval,
    meetingDuration: TimeInterval,
    inboxDuration: TimeInterval,
    customDuration: TimeInterval,
    calendarVideoCallDuration: TimeInterval,
    customTypeDurations: [UUID: TimeInterval]
) {
    var focusTime: TimeInterval = 0
    var meeting: TimeInterval = 0
    var inbox: TimeInterval = 0
    var custom: TimeInterval = 0
    var calendarVideoCall: TimeInterval = 0
    var customTypes: [UUID: TimeInterval] = [:]

    for record in records {
        // Read modeType from FocusMode (load mode from FocusModeService)
        if let mode = FocusModeService.shared.findMode(id: record.modeID) {
            switch mode.typeDescriptor {
            case .builtIn(let type):
                switch type {
                case .focusTime: focusTime += record.duration
                case .meeting: meeting += record.duration
                case .inbox: inbox += record.duration
                case .custom: custom += record.duration
                case .calendarVideoCall: calendarVideoCall += record.duration
                case .userCustom: break  // Should not happen for built-in
                }
            case .custom(let type):
                customTypes[type.id, default: 0] += record.duration
            }
        }
    }

    return (focusTime, meeting, inbox, custom, calendarVideoCall, customTypes)
}
```

**Actualización en `getDailyMetrics`:**
```swift
func getDailyMetrics(for date: Date) -> DailyMetrics? {
    let calendar = Calendar.current
    let targetDay = calendar.startOfDay(for: date)

    let dayRecords = records.filter { record in
        calendar.isDate(record.startTime, inSameDayAs: targetDay)
    }

    guard !dayRecords.isEmpty else { return nil }

    let pomodoros = dayRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
    let meetingTime = dayRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
    let totalFocus = dayRecords.reduce(0) { $0 + $1.duration }
    let breakdown = modeTypeBreakdown(for: dayRecords)

    return DailyMetrics(
        date: targetDay,
        pomodorosCompleted: pomodoros,
        meetingTime: meetingTime,
        totalFocusTime: totalFocus,
        focusTimeDuration: breakdown.focusTimeDuration,
        meetingDuration: breakdown.meetingDuration,
        inboxDuration: breakdown.inboxDuration,
        customDuration: breakdown.customDuration,
        customTypeDurations: breakdown.customTypeDurations,
        calendarVideoCallDuration: breakdown.calendarVideoCallDuration
    )
}
```

### 3.4 Actualización de UI de métricas

**DailyMetricsView:**
```swift
struct DailyMetricsView: View {
    let metrics: DailyMetrics
    @State private var selectedType: FocusTypeDescriptor?

    var body: some View {
        List {
            // Built-in types
            Section("Built-in Types") {
                MetricRow(label: "Focus Time", duration: metrics.focusTimeDuration)
                MetricRow(label: "Meeting", duration: metrics.meetingDuration)
                MetricRow(label: "Inbox", duration: metrics.inboxDuration)
                MetricRow(label: "Custom", duration: metrics.customDuration)
            }

            // Custom types (dinámico)
            if !metrics.customTypeDurations.isEmpty {
                Section("My Types") {
                    ForEach(FocusTypesService.shared.customTypes, id: \.id) { type in
                        let duration = metrics.durationForType(.custom(type))
                        if duration > 0 {
                            MetricRow(
                                label: type.emoji + " " + type.name,
                                duration: duration
                            )
                        }
                    }
                }
            }

            // Calendar video calls
            if metrics.calendarVideoCallDuration > 0 {
                Section("Calendar") {
                    MetricRow(
                        label: "Video Calls",
                        duration: metrics.calendarVideoCallDuration
                    )
                }
            }
        }
    }
}
```

## Arquitectura tecnica

### Nuevos archivos
**Canal calendario:**
- `Focally/Services/CalendarEventAnalyzer.swift`
- `Focally/Services/EmojiExtractor.swift`
- `Focally/Models/SlackCalendarSettings.swift`

**Focus types personalizables:**
- `Focally/Models/FocusType.swift`
- `Focally/Services/FocusTypesService.swift`
- `Focally/Views/Settings/FocusTypesSettingsView.swift`
- `Focally/Views/FocusModes/AddFocusTypeSheet.swift`

### Modificaciones a modelos existentes
- `Focally/Models/FocusMode.swift` (agregar `typeDescriptor`)
- `Focally/Models/FocusModeType.swift` (agregar `calendarVideoCall`, `userCustom`)
- `Focally/Services/FocusMetricsService.swift` (actualizar breakdown)
- `Focally/Models/FocusSessionRecord.swift` (sin cambios, usa modeID)

### Modificaciones a UI existente
- `Focally/Views/Settings/SlackSettingsView.swift` (agregar sección calendario)
- `Focally/Views/FocusModes/FocusModeEditorSheet.swift` (agregar type picker)
- `Focally/Views/Metrics/DailyMetricsView.swift` (mostrar custom types)
- `Focally/Views/Metrics/WeeklyMetricsView.swift` (mostrar custom types)
- `Focally/Views/Metrics/MonthlyMetricsView.swift` (mostrar custom types)

### Localization

**Keys a agregar (EN/ES/PT):**
```
# Calendario
"calendar_section_header" = "Calendar"
"show_calendar_in_slack" = "Show calendar events"
"show_calendar_in_slack_help" = "Shows active event in Slack when no focus mode is active"
"show_full_title" = "Full title"
"show_video_call_only" = "Only 'In video call'"
"hide_title" = "Hide title"
"use_event_emojis" = "Use event emojis"
"use_event_emojis_help" = "Replaces default emoji with event emojis"
"activate_dnd_video_calls" = "Activate DND for video calls"
"in_video_call" = "In video call"
"in_meeting" = "In meeting"

# Focus Types
"focus_type_section_header" = "Focus Types"
"built_in_types_header" = "Built-in Types"
"my_types_header" = "My Types"
"add_new_type" = "Add new type"
"focus_type_name" = "Name"
"focus_type_emoji" = "Emoji"
"focus_type_color" = "Color"
"create_type" = "Create"
"edit_type" = "Edit"
"delete_type" = "Delete"

# Metrics
"calendar_video_calls" = "Video Calls"
```

## Migration plan

**Backward compatibility:**
1. `FocusMode` tiene `type` (legacy) + `typeDescriptor` (nuevo)
2. Decoder usa `type` para inicializar `typeDescriptor` si falta
3. `DailyMetrics` conserva campos `focusTimeDuration`, etc. para compatibilidad
4. `customTypeDurations` default a `[:]` si falta
5. `calendarVideoCallDuration` default a `0` si falta

**Migration code:**
```swift
// In FocusMode decoder
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // ... decode existing fields ...

    // Decode typeDescriptor, fallback to type
    if let descriptor = try container.decodeIfPresent(FocusTypeDescriptor.self, forKey: .typeDescriptor) {
        typeDescriptor = descriptor
    } else {
        let legacyType = try container.decode(FocusModeType.self, forKey: .type)
        typeDescriptor = .builtIn(legacyType)
    }
}
```

## Test cases

### Calendar tests
[Ver tests de la Parte 1 - sin cambios]

### Custom Focus Types tests
**Test 1: Crear nuevo tipo**
```
Input: Name="Lunch", Emoji="🍕", Color="#FF5733"
Expected: Nuevo tipo agregado a FocusTypesService.shared.customTypes
```

**Test 2: Asignar tipo a focus mode**
```
Input: Focus mode "Team standup", typeDescriptor=.custom(Lunch)
Expected: mode.type == .userCustom, mode.typeDescriptor.custom.id == Lunch.id
```

**Test 3: Métricas con custom type**
```
Input: Sesión con custom type "Lunch" (30 min)
Expected: DailyMetrics.customTypeDurations[Lunch.id] == 1800
```

**Test 4: Calendar video call metrics**
```
Input: Evento "Team standup" (zoom, 30 min)
Expected: DailyMetrics.calendarVideoCallDuration == 1800
```

## Security & Privacy considerations
- EventKit permissions ya implementadas
- Solo lectura de eventos, no modificación
- URLs solo para detección, no se envían a Slack
- Custom types guardados en UserDefaults (local)

## Dependencies
- EventKit (ya existente)
- Sin dependencias externas nuevas

## Performance considerations
- Emoji extraction: O(n) donde n es length of title (tipico < 100 chars)
- Video call detection: O(1) checks
- Custom types lookup: O(1) con diccionario
- Metrics aggregation: O(n * m) donde n=records, m=custom types (aceptable)

## Rollback plan
Si hay bugs criticos:
1. Deshabilitar `showCalendarInSlack` (default a false)
2. Deshabilitar `FocusTypesService` (usar solo built-in types)
3. Canal calendar nunca se activa
4. Comportamiento actual preservado
5. Hotfix release v0.9.4.1

## Definition of Done
### Parte 1: Calendario
- Todos los nuevos archivos creados (CalendarEventAnalyzer, EmojiExtractor, SlackCalendarSettings)
- UI agregada en SlackSettingsView
- Localizaciones EN/ES/PT completas
- Integration test: Canal calendar activo cuando no hay focus mode
- Integration test: Canal focus mode ignora calendario
- Integration test: Eventos out of office mostrados correctamente
- Integration test: Emojis extraídos correctamente
- Integration test: Video call metrics registradas

### Parte 2: Custom Focus Types
- Todos los nuevos archivos creados (FocusType, FocusTypesService, UI)
- Modelos actualizados con backward compatibility
- UI agregada en FocusModeEditorSheet (type picker)
- UI agregada en FocusTypesSettingsView
- Localizaciones EN/ES/PT completas
- Integration test: Crear/editar/eliminar custom types
- Integration test: Asignar custom type a focus mode
- Integration test: Custom types persisten entre sesiones

### Parte 3: Métricas
- DailyMetrics actualizado con customTypeDurations
- WeeklyMetrics/MonthlyMetrics actualizados
- Metrics de calendar video calls funcionan
- UI de métricas muestra custom types
- Integration test: Metrics agregan custom types correctamente
- Integration test: Metrics de calendar video calls funcionan

### General
- No regresiones en comportamiento existente
- Build exitoso en Release
- DMG generado
- Release v0.9.4 publicado

## Notes
**Calendario:**
- Calendario y focus modes son canales INDEPENDIENTES
- Solo UN canal activo a la vez (priority: focus mode > calendar > idle)
- Los emojis de Discord NO se extraen, solo Unicode
- Si el evento no tiene emojis y `useEventEmojisForStatus` es true, no se muestra emoji (no fallback)
- La detección de video calls es "best effort" - puede tener falsos positivos/negativos
- El canal calendar NO activa DND de macOS automáticamente (solo Slack, si está configurado)

**Custom Focus Types:**
- Built-in types: Focus Time, Meeting, Inbox, Custom
- Custom types: Creados por el usuario, guardados en UserDefaults
- Type descriptor unificado: `FocusTypeDescriptor` (enum con 2 casos)
- Backward compatibility: `type` field se mantiene para decodificar datos antiguos
- Custom types tienen emoji + color para distinción visual
- No se pueden editar built-in types, solo custom types
- Si se elimina un custom type que tiene sesiones registradas, las métricas se mantienen pero el tipo se muestra como "Unknown"

**Métricas:**
- Calendar video calls se agregan en `DailyMetrics.calendarVideoCallDuration`
- Custom types se agregan en `DailyMetrics.customTypeDurations` (diccionario)
- Built-in types se siguen agregando en campos dedicados (`focusTimeDuration`, etc.)
- Si un custom type es eliminado, sus métricas persisten pero no se muestran en UI (o se muestran como "Unknown")