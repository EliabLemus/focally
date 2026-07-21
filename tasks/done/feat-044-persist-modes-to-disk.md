# FEAT-044: Persistir focus modes a disco (fuera del sandbox)

## Problema
Los focus modes se guardan en UserDefaults (sandbox). Al hacer `brew upgrade`, el container se borra y se pierden los modos creados por el usuario.

## Solución
Guardar una copia de los focus modes como JSON en `~/.focally/modes.json` (fuera del sandbox). Al iniciar:
1. Cargar desde archivo primero (si existe)
2. Si no existe, migrar desde UserDefaults
3. Escribir a ambos (UserDefaults para compatibilidad, archivo para persistencia real)

## Implementación
- Crear `PersistenceService` o agregar método estático en `FocusModeStore`
- Ruta: `FileManager.default.homeDirectoryForCurrentUser/.app-focally/modes.json`
- Al `saveModes()`: escribir a archivo además de UserDefaults
- Al `loadModes()`: leer de archivo primero, fallback a UserDefaults, fallback a builtIn

## Archivos
- `Focally/Models/FocusMode.swift` — FocusModeStore.saveModes / loadModes
- Posible nuevo `Focally/Services/PersistenceService.swift`

## Criterios
- `brew upgrade` NO pierde los modos del usuario
- Si el archivo no existe, se crea en el primer save
- Si el archivo está corrupto, fallback a UserDefaults
- Built-in modes siempre se regeneran (no se borran)