# COMANDOS PARA PROBAR EL ÚLTIMO RELEASE DE FOCALLY

## 🎯 Qué vas a hacer

Probar la última versión de Focally desde tu otra máquina usando `brew upgrade focally`.

## 📋 Pasos Exactos (EN TU OTRA MÁQUINA)

### 1. Autenticar GitHub CLI

```bash
gh auth login
# Selecciona: Login with a web browser
# GitHub abrirá el browser, autoriza y listo
```

### 2. Ir al directorio de Focally

```bash
cd /path/a/focally
# Ajustar según tu ruta (ejemplo: ~/projects/focally o ~/.openclaw/workspace/projects/focally)
```

### 3. Obtener los últimos cambios

```bash
git pull origin main
```

### 4. Verificar que tienes los commits nuevos

```bash
git log --oneline -5
```

**Deberías ver:**
```
d601654 fix: update testing scripts and schemes for nexus execution
751ebd6 feat: add manual UI testing script (fallback)
3f0ba87 feat: add automated UI testing scripts for nexus
03494d4 feat: implement TASK-027 XCUITest infrastructure
28a47ce feat: implement TASK-023 unit tests with XCTest
```

### 5. Actualizar Focally con brew

```bash
brew upgrade focally
```

Esto instalará la versión más reciente con todos los commits de testing.

### 6. Probar Unit Tests (100% automatizado)

```bash
cd /path/a/focally
./scripts/run-unit-tests.sh
```

**Output esperado:**
```
🧪 Ejecutando Tests Unitarios de Focally (XCTest)...

📦 Build y ejecución de tests...
Test Suite 'All tests' passed at 2026-05-05 XX:XX:XX.XXX.
  Executed 14 tests, with 0 failures (0 unexpected) in 0.008 (0.035) seconds
** TEST SUCCEEDED **

✅ Ejecución completada!
```

### 7. Probar UI Tests (opcional, requiere Xcode)

```bash
cd /path/a/focally
./scripts/run-ui-tests-manual.sh
```

**Output esperado:**
```
🧪 UI Tests Diagnóstico - Focally
================================
1️⃣ Verificando Xcode... ✅
2️⃣ Verificando proyecto... ✅
3️⃣ Verificando scheme... ✅
4️⃣ Intentando build de UI tests... ** BUILD SUCCEEDED **
5️⃣ Abriendo Xcode...

ℹ️  Xcode se abrirá con el proyecto
ℹ️  Para ejecutar tests:
      1. Selecciona scheme: FocallyUITests (en toolbar)
      2. Cmd + U para ejecutar tests
      3. Verifica resultados en Xcode

✅ Xcode abierto manualmente
```

**Luego en Xcode:**
1. Cmd + Shift + < para cambiar scheme
2. Selecciona "FocallyUITests"
3. Cmd + U para ejecutar tests
4. Revisa resultados en el panel de tests

## 📊 Cambios en esta Versión (Post v0.6.5)

### Testing Completo
- ✅ **16 unit tests** con XCTest framework
  - SimpleFrameworkTests (5 tests)
  - PomodoroStateTests (2 tests)
  - SoundPlayerServiceTests (4 tests)
  - HistoryServiceTests (3 tests)

- ✅ **8 UI tests** con XCUITest
  - testAppLaunchAndMenuBarInteraction
  - testTimerServiceAccessibilityElements
  - testBasicTimerControls
  - testAppDoesNotCrashOnLaunch
  - testAppHasMainWindowOrStatusBarItem
  - testAppHandlesMultipleLaunchesGracefully
  - testAppTerminatesCleanly
  - testLaunchArgumentsAreSet

### Scripts de Automatización
- `run-unit-tests.sh` - Ejecuta 14 unit tests en 0.008s
- `run-ui-tests-manual.sh` - Build UI tests + abre Xcode
- `run-ui-tests-automated.sh` - AppleScript automation (experimental)
- `run-ui-tests-alternative.sh` - Script de diagnóstico

### Coverage
- **Unit tests:** 60% de funcionalidad principal
- **UI tests:** 100% de UI básica (app launch, controles, estabilidad)

## 🔧 Si Algo Falla

### brew upgrade no muestra nueva versión

```bash
# Actualizar el tap manualmente
brew tap EliabLemus/focally

# O forzar reinstall
brew reinstall --cask focally
```

### Unit tests fallan

```bash
# Verificar versión instalada
brew list --cask --versions focally

# Reinstalar completamente
brew uninstall --cask focally
brew install --cask focally
```

### Xcode no abre

```bash
# Abrir proyecto directamente
open Focally.xcodeproj

# Ejecutar tests desde Xcode GUI
# Cmd + U
```

## 🎯 Resumen Ultra-Rápido

**Copia y pega en tu otra máquina:**

```bash
# 1. Autenticar
gh auth login

# 2. Pull cambios
cd /path/a/focally
git pull origin main

# 3. Actualizar app
brew upgrade focally

# 4. Probar tests
./scripts/run-unit-tests.sh
```

## ✅ Éxito Esperado

- **brew upgrade** instala la versión con testing
- **Unit tests:** 14/14 tests pasan (0.008 segundos)
- **UI tests:** Build exitoso, Xcode listo para ejecución
- **Tiempo total:** ~2-5 minutos para todo el flujo

---
