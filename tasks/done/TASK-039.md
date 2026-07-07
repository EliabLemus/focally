---
id: TASK-039
created: 2026-05-06T19:45:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-039: Implement Drag & Drop Zone for Shortcut Installation

## Contexto
- Issue: Los shortcuts de Apple deben crearse/importarse manualmente → mala UX
- Encontré: SwiftUI `onDrop(of:isTargeted:perform:)` permite recibir archivos `.shortcut` programáticamente
- Encontré: SwiftShortcuts librería para generar archivos `.shortcut` desde código Swift
- Encontré: `shortcuts://import-shortcut?url=...&name=...` deeplink para importar shortcuts desde URLs

## Objetivo
Implementar una zona de **drag & drop** en Focally para que el usuario pueda:
1. Arrastrar archivos `.shortcut` directamente a Focally
2. Focally procese automáticamente los shortcuts:
   - Extraer nombre del shortcut
   - Guardar en `~/Library/Shortcuts/` (o location de Focally)
   - Abrir `shortcuts://import-shortcut?url=...&name=...` para importar automáticamente

## Criterios de aceptación
- [ ] Zona de drop visible en alguna vista de Focally (Settings o dedicada)
- [ ] La zona acepta solo archivos `.shortcut`
- [ ] Al soltar un archivo `.shortcut`:
   - Extrae nombre del archivo
   - Copia a `~/Library/Shortcuts/` (o directorio de Focally)
   - Abre `shortcuts://import-shortcut?url=file:///...&name=...` para importar automáticamente
- [ ] Muestra indicador visual de que el shortcut fue importado exitosamente
- [ ] Si el shortcut ya existe, lo reemplaza (o pregunta confirmación)
- [ ] Integración con `FocusIntegrationService` para detectar shortcuts instalados
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`
- [ ] No requiere permisos especiales (SwiftUI onDrop usa sandbox normal)

## Implementación sugerida

### 1. Crear `ShortcutDropHandler` (nuevo servicio)

```swift
import Foundation
import SwiftUI

struct ShortcutFile: Identifiable {
    let id = UUID()
    let filename: String
    let fileURL: URL
}

class ShortcutDropHandler: ObservableObject {
    @Published var droppedShortcuts: [ShortcutFile] = []

    func importShortcut(from fileURL: URL) -> Bool {
        // 1. Extraer nombre
        let filename = fileURL.lastPathComponent
        let name = filename.replacingOccurrences(of: ".shortcut", with: "")

        // 2. Copiar a ~/Library/Shortcuts/
        let shortcutsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Shortcuts", isDirectory: true)
        try? FileManager.default.createDirectory(at: shortcutsDir, withIntermediateDirectories: true)

        let destinationURL = shortcutsDir.appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            print("✅ Shortcut copiado a: \(destinationURL.path)")

            // 3. Importar automáticamente vía deeplink
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            let deeplink = "shortcuts://import-shortcut?url=file:///\(fileURL.path.replacingOccurrences(of: " ", with: "%20"))&name=\(encodedName)&silent=true"

            if let url = URL(string: deeplink) {
                NSWorkspace.shared.open(url)
                print("✅ Importando shortcut via deeplink: \(deeplink)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    // Verificar si se importó exitosamente
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        // Success: el archivo ahora existe en ~/Library/Shortcuts/
                        return true
                    }
                }
            }
        } catch {
            print("❌ Error importando shortcut: \(error)")
            return false
        }
    }
}
```

### 2. Añadir zona de drop en `IntegrationsSettingsView`

```swift
struct ShortcutDropZone: View {
    @ObservedObject private var dropHandler: ShortcutDropHandler
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Drag & Drop Shortcuts Here")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            if dropHandler.droppedShortcuts.isEmpty {
                Rectangle()
                    .fill(Color.focallySurfaceContainerLowest.opacity(0.5))
                    .frame(height: 150)
                    .overlay(
                        Group {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.focallyOutline)

                            Text("Drop .shortcut files here to install")
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                                .multilineTextAlignment(.center)

                            if isHovering {
                                Text("Release to drop")
                                    .font(.focallyCaption)
                                    .foregroundStyle(Color.focallyOutline)
                            }
                        }
                    )
            } else {
                // Mostrar shortcuts importados
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.focallyPrimary)

                        Text("\(dropHandler.droppedShortcuts.count) shortcut(s) installed")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurface)
                    }

                    ForEach(dropHandler.droppedShortcuts) { shortcut in
                        HStack(spacing: 8) {
                            Text(shortcut.filename)
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurface)

                            Spacer()

                            Button("Remove") {
                                // Remove file and shortcut
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .background(Color.focallySurfaceContainerLowest.opacity(0.5))
                .cornerRadius(FocallyRadius.md)
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
        .onDrop(of: [.shortcut], isTargeted: $isHovering) { providers in
            guard let provider = providers.first else { return }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, error in
                guard let data = data else { return }

                // Intentar decodificar para extraer filename
                if let filename = String(data: data, encoding: .utf8) {
                    let shortcutFile = ShortcutFile(filename: filename, fileURL: URL(fileURLWithPath: filename))
                    dropHandler.importShortcut(from: fileURL)
                }
            }
        }
    }
}

// Extensión para detectar tipo .shortcut
extension UTType {
    static let shortcut = UTType(filenameExtension: "shortcut", conformingTo: .data)
}
```

### 3. Modificar `OnItFocusApp.swift`

```swift
// Agregar ShortcutDropHandler a la composición
@StateObject private var shortcutDropHandler = ShortcutDropHandler()

// Inyectar en IntegrationsSettingsView
ShortcutDropZone(dropHandler: shortcutDropHandler)
```

### 4. Integrar con `FocusIntegrationService`

Detectar shortcuts instalados:

```swift
// En FocusIntegrationService
func checkShortcutsInstalled() -> Bool {
    let shortcutsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Shortcuts", isDirectory: true)
    let requiredShortcuts = ["Focally Focus On", "Focally Focus Off"]

    for shortcutName in requiredShortcuts {
        let shortcutURL = shortcutsDir.appendingPathComponent("\(shortcutName).shortcut")
        if FileManager.default.fileExists(atPath: shortcutURL.path) {
            return true
        }
    }
    }
    return false
}
```

## Contexto de Apple's `shortcuts://import-shortcut`

- **Importante**: `file:///` URLs en macOS necesitan triple slash (`///`)
- Ejemplo correcto: `file:///Users/username/Library/Shortcuts/Name.shortcut`
- El parámetro `silent=true` evita que se abra la UI de Shortcuts

## Prioridad de UX

1. **Indicador visual claro** durante importación
2. **Feedback inmediato** del resultado (✅ o ❌)
3. **Zona de drop destacada** con placeholder visual
4. **Manejo de errores** si la importación falla

## Fuera de scope

- NO implementar generación de shortcuts (eso es otro task)
- Solo manejar archivos `.shortcut` ya creados (por SwiftShortcuts o manualmente)
- NO usar AppleScript ni Automator

---
## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Implementó zona de drag & drop en Settings para instalar shortcuts automáticamente. Al soltar un archivo `.shortcut`, Focally lo copia a `~/Library/Shortcuts/`, abre `shortcuts://import-shortcut?url=file:///...&name=...` para importar automáticamente, y muestra indicador de éxito. Integró ShortcutDropHandler como servicio nuevo y lo inyectó en OnItFocusApp e IntegrationsSettingsView. Build pasó sin errores.
- Archivos nuevos/modificados:
  - `Focally/Services/ShortcutDropHandler.swift` (NUEVO)
  - `Focally/Views/Settings/IntegrationsSettingsView.swift` (MODIFICADO)
  - `Focally/OnItFocusApp.swift` (MODIFICADO)
- Tests: build exitoso
- Notas: La zona de drop usa SwiftUI nativo sin permisos especiales. El deeplink `file:///` necesita triple slash (`///`) en macOS. El parámetro `silent=true` evita que se abra la UI de Shortcuts.
