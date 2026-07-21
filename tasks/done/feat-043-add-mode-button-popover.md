# FEAT-043: Botón "Add Mode" en popover del menú bar

## Problema
El popover del menú bar lista los focus modes para quick start, pero no hay forma de agregar nuevos modos desde ahí. El usuario tiene que abrir la ventana principal → Tasks tab → agregar. Queremos un acceso directo.

## Solución propuesta
Agregar un botón "Add Mode" (o "+") al final de la lista de focus modes en `MenuBarDropdownView.swift` que:
1. Cierre el popover
2. Abra la ventana principal de Focally
3. Navegue al tab de Tasks (donde están los focus modes)

## Implementación
En `MenuBarDropdownView.quickStartSection`:
- Después del `ForEach(focusModeStore.modes)`, agregar un botón:
```swift
Button(action: {
    // Cerrar popover y abrir ventana en tab Tasks
    // Necesita un callback o notification
}) {
    HStack {
        Image(systemName: "plus.circle")
        Text("Add Mode")
    }
    .font(.focallyBody)
    .foregroundStyle(Color.focallyPrimary)
}
```

Para la navegación:
- Pasar un closure `onOpenSettings: () -> Void` desde `OnItFocusApp.swift` al `MenuBarDropdownView`
- El closure cierra el popover, abre la ventana principal (si no está abierta), y selecciona el tab Tasks
- Revisar cómo se navega a tabs actualmente en `MainWindow.swift` / `SidebarView.swift`

## Archivos
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — agregar botón + recibir closure
- `Focally/OnItFocusApp.swift` — pasar closure que abra ventana en tab Tasks
- `Focally/Views/MainWindow.swift` o `Focally/Views/Navigation/SidebarView.swift` — verificar mecanismo de selección de tab

## Criterios de aceptación
- Botón "Add Mode" visible debajo de la lista de focus modes (solo cuando NO hay sesión activa)
- Click cierra el popover y abre la ventana principal en el tab de Tasks
- Si la ventana ya estaba abierta, la trae al frente sin recrearla
- No rompe el flujo existente del popover
- Build + tests pasan
