# TASK-025 — Focally UI Wiring & Polish (Hotfix)

## Estado
**Prioridad**: Alta — bloquea el release correcto de v0.6.0
**Depende de**: TASK-024 (completado, build succeeded)

---

## Problemas identificados (auditoría completa vs Stitch design HTMLs)

### P1: Archivos viejos sin eliminar
Los siguientes archivos siguen existiendo y compilando:

| Archivo | Tamaño | Acción |
|---------|--------|--------|
| `Focally/Views/SettingsView.swift` | 37KB | **Eliminar** |
| `Focally/Views/FocusMenuView.swift` | 16KB | **Eliminar** |
| `Focally/Views/ActivityInputView.swift` | 8KB | **Eliminar** |

### P2: Icono de menu bar incorrecto
- **Actual**: `hourglass` (systemSymbolName) — OnItFocusApp.swift líneas 37 y 247
- **Design Stitch**: `timer` (filled) — usado en menu_bar_state_light/dark y menu_bar_dropdown
- **Cambio**: `"hourglass"` → `"timer"`

### P3: Sidebar — tabs faltan vs design
El design HTML (active_focus_view, menu_bar_state) muestra estas tabs en el sidebar:
- `timer` → Focus/Timer ✅
- `checklist` → Tasks ✅
- `bar_chart` → Analytics ✅
- `settings` → Settings ✅

**Pero el design NO tiene tabs "Schedule" ni "Calendar"** — las tabs son solo 4.

**Actual** (FocallyTab): Timer, Tasks, Schedule, Analytics, Settings (5 tabs)
**Design**: Timer, Tasks, Analytics, Settings (4 tabs)

**Nota**: Schedule existe como vista en el spec TASK-024 y ya está implementada. La decisión es si la conservamos como tab separada o la movemos dentro de otra tab (ej: dentro de Analytics o Timer). **Preguntar a Eliab** antes de eliminar.

### P4: Sidebar — profile card incorrecto
**Design** (active_focus_view): Avatar circular + "Alex Sterling" + "Pro Member"
**Actual** (SidebarView.swift): Avatar con "E" initial + "Eliab" + "Pro Member"

**Problema**: El spec TASK-024 dice "Profile shows 'Eliab' with 'E' initial, no Pro/License text". Pero el design HTML sí muestra "Pro Member". El spec gana sobre el HTML aquí — pero **falta confirmar** si se elimina el "Pro Member" text.

**Acción**: Verificar SidebarView.swift — si dice "Pro Member", eliminarlo.

### P5: Sidebar — falta "Daily Streak" card
**Design** (menu_bar_state_light): Al fondo del sidebar, debajo del profile, hay una card:
```
┌─────────────────┐
│ Daily Streak     │
│ 12 Days     🔥  │
└─────────────────┘
```
**Actual**: No existe en SidebarView.swift

**Nota**: Esto es un feature, no solo visual. Podría ser placeholder con datos mock.

### P6: TopBar — falta badge DND
**Design** (active_focus_view): TopBar tiene un badge a la izquierda:
- `notifications_off` icon (filled, primary) + "Do Not Disturb Active" (caption, uppercase, tracking-widest)
- History button + Settings button a la derecha

**Actual** (TopBarView.swift): Solo tiene History + Settings a la derecha. No hay badge DND.

**Acción**: Agregar DND badge al TopBar (conectado al DNDService real).

### P7: Tasks — no usa bento grid
- **Actual**: Stack vertical — Timer Settings → Flow Mode → Predefined Tasks, todo full-width
- **Design** (task_picker_config): Bento grid de 12 columnas:
  - Timer Settings + Flow Mode: col-span-5 (izquierda, apilados verticalmente)
  - Predefined Tasks: col-span-7 (derecha)
- **Acción**: Reescribir layout de TasksPage.swift

### P8: Tasks — iconos genéricos en predefined tasks
- **Actual**: Todos los tasks usan `chevron.left.forwardslash.chevron.right` + mismo color azul
- **Design** (task_picker_config):
  - Deep Coding: `code`, bg-blue-100, text-blue-600
  - Technical Documentation: `article`, bg-orange-100, text-orange-600
  - Inbox Clearing: `mail`, bg-purple-100, text-purple-600
  - Quick Workout: `fitness_center`, bg-green-100, text-green-600
- **SF Symbol mapping**:
  - `code` → `chevron.left.forwardslash.chevron.right`
  - `article` → `doc.text`
  - `mail` → `envelope`
  - `fitness_center` → `dumbbell`

### P9: Tasks — datos mock hardcoded
- **Actual**: "25m • 4 cycles" para todas
- **Design**: Cada task tiene su duración y ciclos:
  - Deep Coding: 25m • 4 cycles
  - Technical Documentation: 50m • 2 cycles
  - Inbox Clearing: 15m • 1 cycle
  - Quick Workout: 10m • 1 cycle

### P10: Tasks — falta TaskRowView como archivo separado
- **Actual**: `TaskRowView` está anidado dentro de `PredefinedTasksList`
- **Spec**: Archivo separado

### P11: Tasks — falta Smart Templates card
**Design** (task_picker_config): Debajo de la lista de tasks, hay una card:
```
┌─────────────────────────────┐
│ ✨ Smart Templates          │
│ AI can suggest task         │
│ durations based on your     │
│ past performance.           │
│                             │
│ [ Enable AI Insights ]      │
└─────────────────────────────┘
```
- Background: `secondary-fixed` (gris claro)
- Icono: `auto_awesome` (sparkles)
- Botón: "Enable AI Insights" (text button, primary color)

**Actual**: Solo existe un "Coming Soon" badge de una línea — falta la card completa.

### P12: Tasks — falta footer con acciones
**Design** (task_picker_config): Debajo del grid:
- Izquierda: 3 circles de colores (social proof) + "Used by 12,400+ professionals today."
- Derecha: "Discard Changes" button + "Save Configurations" button (primary)

**Actual**: No existe footer.

### P13: Active Focus View — timer tamaño incorrecto
**Design** (active_focus_view): Timer es **160px**, con `:` separator animado (primary/30 opacity, pulsing)
**Actual**: ActiveFocusView.swift — verificar tamaño

### P14: Active Focus View — controles incorrectos
**Design**: Pause y Finish como circles de 64px (w-16 h-16) con label debajo:
- Pause: `secondary-fixed` bg → hover: `secondary-fixed-dim`, icon `pause`
- Finish: `error/10` bg → hover: `error` bg + white text, icon `stop` (filled)

**Actual**: Verificar TimerControlsView.swift coincide

### P15: Active Focus View — bottom cards incorrectas
**Design**: 3 cards en fila al fondo (bento, col-span-4 cada una):
- Focus Score: `bolt` icon + "High" badge + "94%"
- Estimated End: `schedule` icon + "11:45 AM"
- Environment: `self_improvement` icon + "Calm"

**Actual**: FocallyFocusScoreCard.swift + EstimatedTimeCard.swift — verificar que coinciden

### P16: Idle Dashboard — falta "Today's Flow" mini chart
**Design** (menu_bar_state_light): Card "Today's Flow" con 7 barras verticales de diferentes alturas y colores azules
**Actual**: IdleDashboardView.swift — verificar si incluye mini chart

### P17: Idle Dashboard — falta "Up Next" card
**Design** (menu_bar_state_light): Card "Up Next" con:
- "Short Break" (tertiary dot, 5 Minutes)
- "Deep Work: Email Clean" (gray dot, 25 Minutes, opacity 50%)

**Actual**: Verificar IdleDashboardView.swift

### P18: MenuBar Dropdown — diseño parece correcto
La captura de pantalla que envió Eliab muestra el dropdown funcionando en dark mode con el diseño correcto (task input, Start Pomodoro/Custom Session, active session card, footer stats). **Sin cambios needed.**

### P19: Settings — pendiente conexión a servicios
Las sub-vistas son mock. Aceptable por ahora — documentar como pendiente.

---

## Resumen de impacto

| # | Problema | Severidad | Esfuerzo |
|---|----------|-----------|----------|
| P1 | Archivos viejos | Media | Bajo (delete) |
| P2 | Icono menu bar | Alta | Bajo (2 líneas) |
| P3 | Tab Schedule de más | Media | Bajo (preguntar) |
| P4 | Profile "Pro Member" | Baja | Bajo |
| P5 | Daily Streak card | Baja | Medio |
| P6 | TopBar DND badge | Media | Bajo |
| P7 | Tasks bento grid | Alta | Medio |
| P8 | Tasks iconos | Media | Bajo |
| P9 | Tasks datos mock | Baja | Bajo |
| P10 | TaskRowView separado | Baja | Bajo |
| P11 | Smart Templates card | Media | Bajo |
| P12 | Tasks footer | Baja | Bajo |
| P13 | Timer tamaño | Media | Bajo (verificar) |
| P14 | Timer controles | Media | Bajo (verificar) |
| P15 | Bottom cards | Media | Bajo (verificar) |
| P16 | Today's Flow chart | Media | Medio |
| P17 | Up Next card | Media | Medio |
| P18 | MenuBar dropdown | ✅ OK | — |
| P19 | Settings servicios | Baja | Postergado |

---

## Decisiones pendientes (para Eliab)

1. **Schedule tab**: El design original solo tiene 4 tabs (Timer, Tasks, Analytics, Settings). ¿Eliminamos Schedule como tab separada o la mantenemos?
2. **Daily Streak**: ¿Incluimos la card de "Daily Streak" en el sidebar? (feature adicional, no en el spec original)
3. **"Pro Member" text**: El spec dice eliminarlo, el design lo muestra. ¿Lo quitamos?

---

## Plan de ejecución (una vez confirmadas las decisiones)

### Batch 1 — Quick fixes (sin diseño nuevo)
- P1: Eliminar archivos viejos
- P2: Cambiar icono hourglass → timer
- P4: Eliminar "Pro Member" del profile card
- P8: Arreglar iconos de tasks
- P9: Arreglar datos mock de tasks
- P10: Separar TaskRowView

### Batch 2 — Layout fixes
- P7: Bento grid en TasksPage
- P11: Smart Templates card completa
- P12: Footer en TasksPage
- P6: DND badge en TopBar

### Batch 3 — Verificaciones y ajustes
- P13: Verificar tamaño timer (160px)
- P14: Verificar controles (pause/finish circles)
- P15: Verificar bottom cards
- P16: Agregar Today's Flow mini chart
- P17: Agregar Up Next card

### Batch 4 — Build + verify
```bash
xcodegen generate
xcodebuild -scheme Focally -destination 'platform=macOS' build
```

No se toca release hasta que todo esté verificado.
