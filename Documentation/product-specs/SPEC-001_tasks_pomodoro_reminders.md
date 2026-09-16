# SPEC-001: Tasks, Pomodoro Binding y Reminders

> Estado: approved-for-implementation (autónomo, rama `feat/todo-pomodoro-reminders`)
> Fecha: 2026-09-16 · Versión objetivo: v0.10.0

## Objetivo

Focally gana tres capacidades integradas (no un gestor de tareas genérico):

1. **To-do list** — tareas locales, simples, con vencimiento opcional.
2. **Pomodoro por tarea** — cada pomodoro que ya existe (FocusTimerService) puede
   ejecutarse *para* una tarea; el tiempo queda atribuido a esa tarea.
3. **Reminders** — notificación local cuando una tarea vence.

## Research — qué copiamos y de quién

Comparativa de mercado (Focus To-Do, Pomofocus, TickTick, Toggl Track, Be Focused,
Forest; 2026): el patrón dominante es **task binding** — elegir una tarea y arrancar
el timer contra ella; el tiempo se registra automáticamente contra esa tarea.

| Capacidad | Fuente de inspiración | Decisión para Focally |
|---|---|---|
| Timer + lista en una sola vista | Pomofocus, Focus To-Do | Sí: pestaña Tasks con timer embebido |
| Task binding (1 tarea ↔ sesión activa) | Focus To-Do, TickTick | **Sí — núcleo del spec** |
| Tiempo acumulado por tarea | Focus To-Do, Toggl | Sí: suma de `FocusSessionRecord.taskID` |
| Estimación de pomodoros por tarea | Focus To-Do | V2 (no bloquea) |
| Subtareas, proyectos, etiquetas | TickTick | No — anti-alcance |
| Gamificación (árboles) | Forest | No |

Principio: el timer de Focally ya mide y persiste sesiones; no duplicamos nada,
solo **atribuimos** lo que ya mide a una tarea concreta.

## Alcance v1

### 1. TaskItem (modelo)
- `id: UUID`, `title: String` (1–200 chars tras trim, requerido),
  `isCompleted: Bool`, `createdAt: Date`, `dueDate: Date?`,
  `completedAt: Date?`, `estimatedPomodoros: Int?` (V2, reservado),
  `notes: String?` (V2, reservado).

### 2. TaskService (servicio singleton, patrón SERVICE_PATTERN.md)
- ObservableObject con `@Published var tasks: [TaskItem]`.
- Persistencia JSON en `~/.focally/tasks.json` (mismo home que
  `SessionPersistenceService`), escritura atómica, carga perezosa al iniciar.
- CRUD: `add`, `update`, `remove`, `toggleComplete`, `reorder(from:to:)`.
- Orden: pendientes primero por `dueDate` asc (nil al final), luego
  `createdAt` asc; completadas al final por `completedAt` desc.
- Cap 500 tareas (misma filosofía MVP que FocusMetricsService.maxRecords).
- Tareas completadas se conservan (historial de tiempo atribuido).

### 3. Binding pomodoro ↔ tarea
- `PersistedFocusSession.taskID: UUID?` (schema v1 → **v2**, opcional, retrocompatible:
  decode de v1 sin taskID funciona; v1 viejo sigue leyéndose por `schemaVersion` guard existente).
- `FocusTimerService.startSession(draft:)` acepta `taskID: UUID?` (nil = sesión libre).
- Al completar sesión, `FocusSessionRecord.taskID` se propaga a métricas.
- Regla: **una sesión pertenece a máx. una tarea**. Cambiar de tarea con sesión
  activa = la sesión activa mantiene su tarea original (simple y predecible).
- La app restaura el binding tras relaunch (viene del snapshot persistido).

### 4. Tiempo por tarea (metrics)
- `TaskService.timeSpent(on taskID:) -> TimeInterval` = suma de
  `activeDuration` de `FocusSessionRecord` donde `taskID` coincida.
- `TaskService.completedPomodoros(on taskID:) -> Int` = suma `pomodorosCompleted`.
- Fuente única de verdad: `FocusMetricsService.records` (no duplicamos almacenamiento).
- En la pestaña Tasks: tiempo total y pomodoros por tarea, visible en la fila.

### 5. Reminders
- Si `dueDate != nil`: `UNUserNotificationCenter` request con identificador
  `task-reminder-<uuid>` (idempotente: re-agendar reemplaza).
- Trigger: calendario en `dueDate` (si ya pasó al agendar, no se notifica).
- Al completar o borrar la tarea: `removePendingNotificationRequests`.
- Texto: título de la tarea; cuerpo "Task due now / Tarea vence ahora / Tarefa vence agora".
- Permiso: se pide con el mismo `requestAuthorization` existente (NotificationService)
  la primera vez que el usuario agenda un reminder.

### 6. UI — nueva pestaña "Tasks" (segunda posición, tras Timer)
- `FocallyTab.tasks` — icono `checklist`, en `visibleTabs` entre timer y metrics.
- Lista con: checkbox, título, tiempo acumulado formateado, badge de pomodoros,
  vencimiento con color de urgencia (vencida/ hoy / futura).
- Creación: campo inline arriba (Enter crea). Edición de título inline.
- Botón play por tarea → abre sheet de confirmación del pomodoro (usa
  `FocusSessionDraft` con actividad = título de la tarea, taskID seteado).
- Si hay sesión activa: la fila muestra "en curso" y el botón se deshabilita
  (la sesión mantiene su tarea).
- Vencidas: sección colapsable arriba.
- Accesibilidad: labels `tasks_*` siguiendo el patrón `accessibilityLabel` existente.

### 7. i18n
- Todas las cadenas nuevas en `en/es/pt.lproj/Localizable.strings` con prefijo
  `task_` / `tab_tasks`. Sin hardcoded strings (regla del repo).

## Fuera de alcance v1 (explícito)
- Sync/nube, proyectos, subtareas, etiquetas, repetición, estimaciones editables,
  widgets, menubar extra, integración Slack/DND por tarea.

## Criterios de aceptación (verificables)
- [ ] AC1 Crear, editar, completar, reordenar y borrar tareas; sobrevive relaunch.
- [ ] AC2 Arrancar pomodoro desde una tarea deja `taskID` en la sesión persistida
      y en `FocusSessionRecord` al completar.
- [ ] AC3 La pestaña Tasks muestra tiempo y pomodoros acumulados por tarea.
- [ ] AC4 Con dueDate futura llega notificación local a la hora exacta (id: `task-reminder-<uuid>`);
      al completar/borrar desaparece del centro de notificaciones pendiente.
- [ ] AC5 Sesión sin tarea (flujo Timer normal) funciona igual que hoy (cero regresión).
- [ ] AC6 Build Release verde + tests de modelos/servicios en verde.
- [ ] AC7 Sin strings hardcoded; en/es/pt completos.

## Riesgos y mitigaciones
| Riesgo | Mitigación |
|---|---|
| Migración schema v1→v2 del snapshot rompe restore | `taskID` opcional con decode tolerante; test de round-trip v1 y v2 |
| Notificaciones sin permiso | Request lazy solo al agendar; fallo silencioso + estado en UI |
| Doble fuente de verdad de tiempo | Solo lectura de FocusMetricsService; TaskService no persiste tiempo |
| Regresión del flujo Timer existente | taskID default nil; todos los call sites actuales sin cambio de comportamiento |
