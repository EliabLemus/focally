# Fix 4: Clickable areas — solo las letras son clickeables

## Problema
En toda la UI de Focally, los elementos clickeables (cards del dashboard, items del sidebar, botones) solo responden al click cuando se hace directamente sobre el texto. El área restante del elemento (padding, background, iconos) no es clickeable.

## Análisis
Esto es un problema clásico de SwiftUI donde `Button` con `.plain` button style puede tener hit-testing limitado cuando el contenido tiene `Spacer()` o cuando el `contentShape` no está definido.

Posibles causas:
1. `FocusModeCard` — el `Button(action: onStart)` envuelve toda la card pero `.buttonStyle(.plain)` + `Spacer()` puede estar absorbiendo el hit test en las áreas vacías
2. `SidebarItemView` — similar: `Button` con `.plain` y `Spacer()`
3. `addModeButton` — `Button` con `.plain` y padding/background

## Solución
Para cada componente clickeable que tenga este problema:
1. Agregar `.contentShape(Rectangle())` al contenido del Button para que todo el área sea clickeable
2. Alternativa: usar `.contentShape(HitTestableShape)` o envolver en un `ZStack` con `contentShape`

Archivos a revisar y fixear:
- `Focally/Views/Timer/FocusModeCard.swift` — `.contentShape(Rectangle())` en el contenido del Button
- `Focally/Views/Timer/IdleDashboardView.swift` — `addModeButton` same fix
- `Focally/Views/Shared/SidebarItemView.swift` — `.contentShape(Rectangle())` en el contenido del Button
- Cualquier otro componente con el mismo patrón

## Acceptance Criteria
- Click en cualquier parte de una card del dashboard → inicia la sesión (no solo en el texto)
- Click en cualquier parte del item del sidebar → navega (no solo en el label)
- Click en cualquier parte del botón "Add Mode" → abre el sheet
- No hay áreas "muertas" dentro de los elementos clickeables
