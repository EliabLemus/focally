# Spec: Categoría de Meeting con Selección de Tiempo

**Fecha**: 2025-01-23
**Prioridad**: High
**Estado**: Draft

## Resumen

Agregar una nueva categoría de tareas llamada "Meeting" que permita al usuario seleccionar una duración específica de tiempo (en meeting) y, al activarla, actualizar el status de Slack con el icono `:google-meet:`.

## Requisitos Funcionales

### 1. Nuevo Tipo de Categoría

#### 1.1 Enum `TaskType`
Crear un nuevo enum para distinguir entre tipos de tareas:

```swift
enum TaskType: String, Codable, CaseIterable {
    case pomodoro = "pomodoro"
    case deepWork = "deepWork"
    case meeting = "meeting"
    
    var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .deepWork: return "Deep Work"
        case .meeting: return "Meeting"
        }
    }
}
```

#### 1.2 Extensión de `PredefinedTask`
Agregar propiedades a `PredefinedTask`:

```swift
struct PredefinedTask: Identifiable, Codable, Equatable {
    // ... propiedades existentes ...
    
    var taskType: TaskType
    var availableDurations: [Int] // Duraciones disponibles en minutos
    
    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         icon: String,
         iconBgColor: String,
         iconFgColor: String,
         durationMinutes: Int = 25,
         cycles: Int = 1,
         taskType: TaskType = .pomodoro,
         availableDurations: [Int] = []) {
        // ...
    }
}
```

### 2. Duración Configurable para Meeting

#### 2.1 Duraciones Predeterminadas
Para meetings, las duraciones disponibles deben ser:
- 15 minutos
- 30 minutos
- 45 minutos
- 60 minutos
- 90 minutos
- 120 minutos

#### 2.2 UI de Selección de Tiempo
Crear un componente `MeetingDurationPicker` que permita seleccionar la duración:

```swift
struct MeetingDurationPicker: View {
    @Binding var selectedDuration: Int
    let availableDurations: [Int]
    
    var body: some View {
        Picker("Duración", selection: $selectedDuration) {
            ForEach(availableDurations, id: \.self) { minutes in
                Text(durationText(minutes)).tag(minutes)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private func durationText(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}
```

### 3. Integración con Slack

#### 3.1 Icono `:google-meet:`
Modificar el flujo de actualización de Slack para usar el icono `:google-meet:` cuando el tipo de tarea es `meeting`.

#### 3.2 Modificación en `FocusIntegrationService`
Actualizar el método `updateSlackStatus` para usar el icono correcto:

```swift
private func updateSlackStatus(for task: PredefinedTask) {
    let emoji: String
    let text: String
    
    switch task.taskType {
    case .meeting:
        emoji = ":google-meet:"
        text = "En meeting"
    case .deepWork:
        emoji = "🧠"
        text = "Deep work"
    case .pomodoro:
        emoji = task.emoji
        text = "Focus time"
    }
    
    slackService.setSlackFocusStatus(text: text, emoji: emoji)
}
```

### 4. Task Predefinida de Meeting

Agregar una tarea predefinida de meeting a `PredefinedTask.defaultTasks`:

```swift
static let defaultTasks: [PredefinedTask] = [
    // ... tareas existentes ...
    PredefinedTask(
        name: "Meeting",
        emoji: "📅",
        icon: "calendar",
        iconBgColor: "E0F2FE",
        iconFgColor: "0369A1",
        durationMinutes: 30,
        cycles: 1,
        taskType: .meeting,
        availableDurations: [15, 30, 45, 60, 90, 120]
    )
]
```

## Cambios en UI

### 1. Lista de Tareas Predefinidas
Actualizar `PredefinedTasksList` para mostrar el tipo de tarea y permitir selección de duración cuando sea un meeting.

### 2. Inicio de Meeting
Crear flujo especial para meetings:
1. Usuario selecciona "Meeting"
2. Se muestra picker de duración
3. Usuario selecciona duración
4. Se inicia timer con duración seleccionada
5. Se actualiza Slack con `:google-meet:`

## Archivos a Modificar

1. **Focally/Models/PredefinedTask.swift**
   - Agregar enum `TaskType`
   - Agregar propiedades `taskType` y `availableDurations`
   - Agregar tarea predefinida de meeting

2. **Focally/Services/FocusIntegrationService.swift**
   - Modificar `updateSlackStatus` para detectar tipo meeting
   - Usar `:google-meet:` para meetings

3. **Focally/Views/Tasks/PredefinedTasksList.swift**
   - Mostrar tipo de tarea
   - Mostrar picker de duración para meetings

4. **Nuevo: Focally/Views/Shared/MeetingDurationPicker.swift**
   - Componente reutilizable para selección de duración

## Validación

### Tests Manuales

1. **Selección de Meeting**
   - [ ] La tarea "Meeting" aparece en la lista
   - [ ] Al seleccionarla, se muestra el picker de duración
   - [ ] Las duraciones disponibles son: 15m, 30m, 45m, 60m, 90m, 120m

2. **Inicio de Meeting**
   - [ ] Al seleccionar duración y comenzar, el timer inicia correctamente
   - [ ] La duración del timer corresponde a la seleccionada

3. **Integración con Slack**
   - [ ] El status de Slack muestra texto "En meeting"
   - [ ] El emoji en Slack es `:google-meet:` (o representación Unicode equivalente)
   - [ ] Al terminar el meeting, el status se limpia correctamente

### Edge Cases

1. **Meeting sin duración seleccionada**
   - [ ] Usar duración por defecto de 30 minutos

2. **Slack deshabilitado**
   - [ ] El meeting funciona sin intentar actualizar Slack

3. **Meeting interrumpido**
   - [ ] El status de Slack se limpia al detener

## Notas Técnicas

- El shortcode `:google-meet:` en Slack es un emoji personalizado. Si el workspace no lo tiene instalado, se debe usar un fallback como "📅" o "📞"
- Considerar agregar validación en `SlackService` para verificar si `:google-meet:` está disponible en el workspace
- La duración seleccionada debe persistirse en `UserDefaults` para futuros meetings

## Consideraciones Futuras

- Permitir duración personalizada (input manual de minutos)
- Sincronizar duración con eventos de Google Calendar
- Agregar más categorías con duración configurable (ej. Code Review)