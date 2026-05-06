# Procedimiento para Hacer Releases de Focally

## Contexto y Lecciones Aprendidas

### Problemas Comunes (2026-05-06)

1. **Sync entre código local y GitHub**
   - El workflow de CI usaba código viejo aunque el tag apuntara al commit correcto
   - **Causa**: Algunos archivos no se commitearon correctamente (`FocusTimerService.swift`)
   - **Solución**: Verificar TODOS los archivos modificados antes de commitear

2. **Compilador Swift estricto en CI**
   - Local compila, pero CI falla con errores de inferencia de tipos
   - **Causa**: CI usa Swift más estricto que el entorno local
   - **Solución**: Agregar anotaciones de tipo explícitas para closures y parámetros

3. **Tags múltiples y confusión**
   - Varios tags (`v0.7.0`, `v0.7.1`) causan confusión
   - **Solución**: Borrar tags viejos y usar un solo tag por versión

## Procedimiento Estándar para Hacer Releases

### 1. Preparación del Código

```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally

# Verificar qué archivos están modificados
git status --short

# Asegurarse de que TODOS los archivos necesarios están stagged
git add .

# Commitear cambios
git commit -m "feat: descripción concisa de los cambios"
```

**IMPORTANTE**: Verificar que TODOS los archivos están incluidos, especialmente:
- Archivos `.swift` nuevos o modificados
- `Focally.xcodeproj/project.pbxproj` (si se agregaron archivos nuevos al proyecto)
- `project.yml` (si hay bump de versión)

### 2. Bump de Versión

```bash
# Editar project.yml
vim project.yml

# Cambiar:
# MARKETING_VERSION: "0.6.4" -> "0.7.0"
# CURRENT_PROJECT_VERSION: "13" -> "14"

# Commitear el bump
git add project.yml
git commit -m "chore: bump version to X.Y.Z, build N"
```

**Regla de versionado**:
- `0.X.Y` → 0.7.0 (cambio mayor, nueva feature grande)
- `0.X.Y` → 0.6.5 (cambio menor, bug fixes)
- `0.X.Y` → 0.6.4.1 (patch, hotfix crítico)

### 3. Verificar Build Local

```bash
# Build en Debug primero
xcodebuild -scheme Focally -configuration Debug build

# Si pasa, hacer build en Release
xcodebuild -scheme Focally -configuration Release build

# Verificar que el .app se creó
find ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Release -name "Focally.app"
```

**CRÍTICO**: Si el build falla local, NO hacer push. Arreglar primero.

### 4. Push al Repo Principal

```bash
# Usar PAT de GitHub (deploy key no tiene permisos de escritura)
git config --local credential.helper 'store --file=/tmp/git-cred'
echo "https://$(gh auth token)@github.com" > /tmp/git-cred

# Push main
git push origin main
```

### 5. Crear Tag

```bash
# Crear tag de versión
git tag v0.7.0 HEAD

# Verificar que el tag apunta al commit correcto
git show v0.7.0 --stat

# Push tag
git push origin v0.7.0
```

**IMPORTANTE**:
- El tag debe apuntar a `HEAD` (último commit del main)
- Usar formato semántico: `vX.Y.Z` donde X=mayor, Y=menor, Z=patch
- Solo un tag por versión

### 6. Monitorear Workflow de GitHub Actions

```bash
# Ver último workflow
gh run list --repo EliabLemus/focally --limit 1

# Ver logs del workflow (si falla)
gh run view --repo EliabLemus/focally --log <workflow-id> | grep -A5 "error:"

# Esperar a que termine (puede tomar 3-5 minutos)
sleep 180
gh run list --repo EliabLemus/focally --limit 1
```

**Estados del workflow**:
- `queued` → Esperando ejecución
- `in_progress` → Compilando
- `success` → ¡Release exitoso!
- `failure` → Revisar logs y arreglar

### 7. Verificar Release

```bash
# Listar releases
gh release list --repo EliabLemus/focally

# Ver detalles del último release
gh release view --repo EliabLemus/focally v0.7.0

# Verificar que el DMG existe
gh release view --repo EliabLemus/focally v0.7.0 --json assets
```

### 8. Verificar Homebrew Tap

```bash
# Ver versión en el cask
gh api repos/EliabLemus/homebrew-focally/contents/Casks/focally.rb --jq '.content' | base64 -d | grep "version"

# Ver SHA256
gh api repos/EliabLemus/homebrew-focally/contents/Casks/focally.rb --jq '.content' | base64 -d | grep "sha256"
```

### 9. Probar el Release (Opcional)

```bash
# En otra máquina o entorno limpio:
brew update && brew upgrade --cask focally

# Verificar que la app se instala y abre
open -a Focally
```

## Troubleshooting

### Problema: Build falla en CI pero pasa local

**Síntomas**:
- Local: `xcodebuild` → `BUILD SUCCEEDED`
- CI: `error: cannot infer type of closure parameter` / `error: extra arguments`

**Solución**:
1. Agregar anotaciones de tipo explícitas a closures problemáticos
2. Ejemplo: `.sink { [weak self] _ in` → `.sink { [weak self] (_: Never) in`
3. Ejemplo: `lazy var timerService = FocusTimerService(...)` → `private lazy var timerService: FocusTimerService = FocusTimerService(...)`

**Archivos comunes con problemas**:
- `Focally/OnItFocusApp.swift` → closures de Combine
- `Focally/Services/*.swift` → inyección de dependencias

### Problema: CI usa código viejo aunque el tag sea correcto

**Síntomas**:
- Tag apunta al commit correcto (`git show v0.7.0 --stat`)
- CI usa código anterior (error en línea que ya fue arreglada)

**Solución**:
1. Verificar que TODOS los archivos modificados están commiteados
2. Ejemplo: `FocusTimerService.swift` tenía parámetros viejos
3. Commitear el archivo faltante: `git add Focally/Services/FocusTimerService.swift`
4. Push: `git push origin main`
5. Actualizar tag: `git tag -d v0.7.0 && git tag v0.7.0 HEAD && git push origin v0.7.0 --force`

### Problema: Deploy key no tiene permisos de escritura

**Síntomas**:
- `ERROR: Permission to EliabLemus/focally.git denied to deploy key`

**Solución**:
1. Usar `gh` CLI con PAT de GitHub
2. Configurar credenciales:
   ```bash
   git config --local credential.helper 'store --file=/tmp/git-cred'
   echo "https://$(gh auth token)@github.com" > /tmp/git-cred
   ```
3. Push con `https://` en lugar de `git@github.com:`

### Problema: Workflow falla con error de `xcodegen`

**Síntomas**:
- `Created project at /Users/runner/work/focally/focally/Focally.xcodeproj`
- `** BUILD FAILED **`

**Solución**:
1. Ejecutar `xcodegen generate` localmente antes de commitear
2. Verificar que el proyecto se generó sin errores
3. Commitear `Focally.xcodeproj/project.pbxproj` si cambió

## Checklist para Releases

Antes de hacer push:

- [ ] Todos los archivos modificados están commiteados
- [ ] `project.yml` tiene versión y build bumpados
- [ ] Build local pasa: `xcodebuild -scheme Focally -configuration Release build`
- [ ] Tag creado: `git tag v0.7.0 HEAD`
- [ ] Tag verificado: `git show v0.7.0 --stat`
- [ ] Credenciales GitHub configuradas
- [ ] Push main: `git push origin main`
- [ ] Push tag: `git push origin v0.7.0`

Después del workflow:

- [ ] Workflow success: `gh run list --limit 1 --json conclusion`
- [ ] Release creado: `gh release list --limit 1`
- [ ] DMG subido: `gh release view v0.7.0 --json assets`
- [ ] Homebrew tap actualizado: versión y SHA256 correctos
- [ ] Prueba de instalación: `brew upgrade --cask focally`

## Referencias

- **Repo principal**: `EliabLemus/focally`
- **Homebrew tap**: `EliabLemus/homebrew-focally`
- **Workflow**: `.github/workflows/release.yml`
- **Build script**: `scripts/build-release.sh`
- **Configuración**: `project.yml`

## Actualizaciones

- **2026-05-06**: Versión inicial basada en troubleshooting del release v0.7.1
  - Agregada verificación de archivos faltantes
  - Agregada guía de anotaciones de tipo para Swift
  - Agregada solución para deploy key sin permisos
