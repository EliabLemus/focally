# EXEC-001: Tasks, Pomodoro Binding y Reminders

> Implementa SPEC-001. Rama: `feat/todo-pomodoro-reminders` · base v0.9.9 (b82)
> Flujo: commits pequeños y verificables; sin push; sin release (requiere aprobación).

## Orden de implementación (cada paso = build verde antes del siguiente)

### Fase 1 — Modelo y servicio (sin UI)
1. [ ] `Sources/Focally/Models/TaskItem.swift` — modelo + validación + orden
2. [ ] `Sources/Focally/Services/TaskService.swift` — CRUD + persistencia JSON
       `~/.focally/tasks.json` (patrón SessionPersistenceService: init inyectable
       fileURL/now, escritura atómica, tolerante a I/O)
3. [ ] Tests: `FocallyTests/TaskItemTests.swift`, `FocallyTests/TaskServiceTests.swift`
       (CRUD, persistencia round-trip, orden, cap 500, corrupto → [] como active_session)

### Fase 2 — Binding pomodoro → tarea
4. [ ] `PersistedFocusSession.taskID: UUID?` — **SIN bump de schema** (hallazgo:
       `isValid` es estricto con `schemaVersion`; v2 perdería sesiones activas al
       actualizar. Campo opcional en v1 = decode de datos viejos → nil, cero riesgo)
5. [ ] `FocusSessionRecord.taskID: UUID?` (opcional, default nil, decode legacy OK)
6. [ ] `FocusTimerService.startSession(draft:taskID:)` + propagación a record + restore
7. [ ] `TaskService.timeSpent(on:)` / `completedPomodoros(on:)` leyendo FocusMetricsService
8. [ ] Tests: round-trip v1/v2, propagación taskID, agregación por tarea, sesión nil-task intacta

### Fase 3 — Reminders
9. [ ] `TaskReminderScheduler.swift` (protocolo + impl UNUserNotificationCenter,
       inyectable para tests; ids `task-reminder-<uuid>`)
10. [ ] Hook en TaskService: add/update/remove/toggle → schedule/cancel
11. [ ] Tests: schedule en fecha futura, no agenda pasada, cancel al completar/borrar

### Fase 4 — UI
12. [ ] `FocallyTab.tasks` (icono `checklist`) en visibleTabs posición 2
13. [ ] `TasksPage.swift` + `TaskRowView.swift` + `AddTaskField.swift`
       + `StartPomodoroSheet.swift` (usa FocusSessionDraft + taskID)
14. [ ] MainWindow: case .tasks
15. [ ] Strings en/es/pt (prefijo task_, tab_tasks)
16. [ ] Tests UI-ligeros: orden de filas, estado vacío, formatos

### Fase 5 — Gates y cierre
17. [ ] xcodegen generate + build Release verde completo
18. [ ] Suite de tests verde
19. [ ] Revisión adversarial acotada del diff (presupuesto duro: 1 diff, ≤8 llamadas)
20. [ ] Commits atómicos por fase; status file en workspace; NO push, NO tag, NO release
21. [ ] Reporte matutino programado (cron 08:30 GT) con estado real y comandos de verificación

## Decisiones técnicas cerradas
- taskID **opcional** en session y record: migración trivial, cero regresión.
- Tiempo por tarea = agregación de records existentes (fuente única).
- Reminder via UNUserNotificationCenter (ya es el stack de NotificationService).
- Pestaña nueva en vez de incrustar en Timer: el Timer queda intacto (AC5).

## Comandos de verificación
```bash
cd ~/Projects/focally
xcodegen generate
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release \
  -destination 'platform=macOS' -derivedDataPath DerivedData/gates \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```
