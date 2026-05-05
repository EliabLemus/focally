# TASK-003: Agregar livecheck al tap de Homebrew + corregir flujo de release

## Status
**PENDIENTE** — Requiere implementación

## Fecha
2026-04-30

## Priority
Alta — El usuario no puede actualizar sin hacks manuales

## Contexto

### El problema
Cuando Eliab corre `brew upgrade --cask focally`, brew usa el tap local (clonado en `/opt/homebrew/Library/Taps/eliablemus/homebrew-focally/`) que puede estar desactualizado. Brew NO hace `git pull` automáticamente al correr `brew upgrade` — necesita `brew update` primero.

Esto causó que Eliab tuviera el tap en v0.3.0 mientras la release v0.4.1 ya existía, resultando en un 404 al intentar descargar el DMG.

### ¿Por qué livecheck?
`livecheck` es el mecanismo oficial de Homebrew para detectar nuevas versiones disponibles en upstream. Sin livecheck, brew solo sabe de la versión que está en el archivo `.rb` del tap local. Con livecheck, brew puede consultar GitHub Releases directamente y decirle al usuario "hay versión nueva disponible".

Esto NO elimina la necesidad de `brew update` para actualizar el tap (y por ende la versión/sha256), pero hace que `brew outdated` funcione correctamente detectando cuándo hay una release nueva.

### Dos repos involucrados
1. **EliabLemus/focally** — La app (SwiftUI, macOS)
2. **EliabLemus/homebrew-focally** — El tap de Homebrew

## Cambios requeridos

### 1. Actualizar el tap (homebrew-focally)

**Archivo:** `Casks/focally.rb`

Agregar bloque `livecheck` que use la estrategia `:github_latest` para detectar releases:

```ruby
cask "focally" do
  version "0.4.1"
  sha256 "5c1b1ec3b62d3a5e06475bec8aa0024d3e8ff88d9192a90c9a65169536b605f4"

  url "https://github.com/EliabLemus/focally/releases/download/v#{version}/Focally-v#{version}.dmg"
  name "Focally"
  desc "Minimal macOS menu bar focus timer with automatic DND and Slack status"
  homepage "https://github.com/EliabLemus/focally"

  app "Focally.app"

  zap trash: [
    "~/Library/Application Support/Focally",
    "~/Library/Preferences/app.focally.mac.plist",
  ]

  livecheck do
    url :url
    strategy :github_latest
  end
end
```

**Por qué `:github_latest`:**
- Nuestro release workflow en GitHub Actions crea releases con tag `v*` (ej: v0.4.1)
- El DMG se nombra `Focally-v{version}.dmg`
- `:github_latest` consulta la API de GitHub para obtener la última release y extrae la versión del tag
- Es la estrategia recomendada por Homebrew para repos que usan GitHub Releases

**Nota:** También se puede usar `:git` (lee tags del repo), pero `:github_latest` es más preciso porque solo considera releases publicados (no tags sueltos).

### 2. Actualizar el workflow CI (focally/.github/workflows/release.yml)

El template del tap que genera el CI debe incluir el bloque `livecheck`:

```ruby
          livecheck do
            url :url
            strategy :github_latest
          end
```

Esto va al final del `cat > Casks/focally.rb << EOF` en el step "Update Homebrew Tap".

### 3. Actualizar README.md de focally

Cambiar las instrucciones de install/upgrade a:

```markdown
## Install

brew tap EliabLemus/focally
brew install --cask focally

## Upgrade

brew update && brew upgrade --cask focally
```

El `brew update` es **obligatorio** — es lo que hace `git pull` del tap remoto.

## Testing checklist

- [ ] Correr `brew livecheck eliablemus/focally/focally` → debe mostrar la versión actual
- [ ] Correr `brew update && brew outdated --cask` → focally debe aparecer si hay versión nueva
- [ ] Correr `brew update && brew upgrade --cask focally` → debe descargar e instalar sin errores
- [ ] Verificar que el DMG se descarga correctamente (URL con `v` prefix)
- [ ] Verificar que sha256 coincide

## Acceptance criteria

- ✅ `brew livecheck` detecta la última versión desde GitHub Releases
- ✅ `brew update && brew upgrade --cask focally` funciona sin hacks manuales
- ✅ El CI genera el tap con `livecheck` incluido automáticamente
- ✅ El README documenta el comando correcto de upgrade

## Dependencies

- **Repo app:** EliabLemus/focally
- **Repo tap:** EliabLemus/homebrew-focally

## Lecciones aprendidas

1. **`brew upgrade` NO actualiza taps** — siempre necesita `brew update` primero
2. **El tap local puede estar desactualizado** — `brew tap --force` NO garantiza `git pull`
3. **El flujo correcto siempre es:** `brew update && brew upgrade`
4. **`livecheck` permite a brew detectar nuevas versiones** consultando GitHub directamente
5. **El DMG se nombra con `v` prefix** (del tag) → la URL del tap debe coincidir: `Focally-v#{version}.dmg`
