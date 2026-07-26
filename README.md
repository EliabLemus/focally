<div align="center">

<img src="https://raw.githubusercontent.com/EliabLemus/focally/main/Focally/Assets.xcassets/AppIcon.appiconset/icon_512x512%402x.png" alt="Focally Icon" width="128">

# Focally

**Focus sessions, managed.**

A minimal macOS menu bar app that handles Do Not Disturb, Slack status, and timer — so you can focus on what matters.

[![Build](https://github.com/EliabLemus/focally/actions/workflows/release.yml/badge.svg)](https://github.com/EliabLemus/focally/actions)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://github.com/EliabLemus/focally)
[![Release](https://img.shields.io/badge/release-v0.9.0-green)](https://github.com/EliabLemus/focally/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

## Why Focally?

We looked at every focus app out there. None did what we needed:

- **Timing apps** (Pomodone, Session) — no DND, no Slack sync
- **Menu bar timers** (Thyme, Hour) — no status integration
- **Productivity suites** (RescueTime, Forest) — heavy, expensive, opinionated

Focally is one thing: **start a timer, get in the zone, let the app handle the rest.** No subscriptions, no bloat, no cloud dependency.

## Features

### Three Focus Modes

| Mode | What it does |
|------|-------------|
| 🎯 **Focus Time** | Classic timer (25/45/60/custom min) with DND + Pomodoro + Slack sync |
| 📋 **Meeting** | Fixed-duration session, keeps DND active, syncs Slack |
| 📥 **Inbox** | Quick triage session with separate sound settings |
| ➕ **Custom** | Create unlimited custom modes with any emoji, status, duration, and optional Pomodoro |

### Integrations

| Feature | Description |
|---------|-------------|
| Direct System DND | Toggles macOS Do Not Disturb via CFPreferences — no setup needed |
| Signed Apple Shortcuts | Pre-signed `.shortcut` files for DND backup — one-button install |
| App Intents | Start / Pause / Resume / End Focus via Shortcuts, Spotlight & Siri |
| Slack Status Sync | Updates status + emoji per focus mode |
| macOS Calendar | Detects meetings through EventKit with no OAuth setup |
| Calendar → Slack + DND | Updates Slack status during meetings and enables DND for video calls |

### App Features

| Feature | Description |
|---------|-------------|
| Sound system | Per-mode sounds (work, break, completion) with live preview |
| Custom Slack emoji | Workspace emoji rendering with persistent disk cache |
| Session history | Full log of past focus sessions with analytics |
| Schedule management | Set recurring focus blocks |
| Onboarding wizard | Guided first-launch setup |
| Keychain secrets | All tokens stored securely in macOS Keychain |

## Installation

### Homebrew (Recommended)

```bash
# Add tap
brew tap EliabLemus/focally

# Install
brew install --cask focally
```

### Direct Download

Download the latest DMG from [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest).

1. Open the DMG
2. Drag **Focally.app** to **Applications**
3. Launch from Applications folder (or Spotlight search)
4. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility → Add Focally)

## Updates

### Homebrew

```bash
# Update homebrew and upgrade Focally
brew update && brew upgrade --cask focally
```

**Note**: If Homebrew refuses to upgrade, use:
```bash
brew reinstall --cask focally
```

### Direct Download

1. Download latest DMG from [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest)
2. Open the DMG
3. Drag **Focally.app** to **Applications** (replace when prompted)
4. Relaunch Focally

**Update Checker**: Focally automatically checks for updates every 24 hours. If a new version is available, you'll see an "Update available" indicator in **Settings → About**. Click it to open the download page.

---

## How it works

| Step | What happens |
|------|-------------|
| **Start** | Pick a mode + activity + duration → timer begins |
| **Focus** | Direct DND activates, signed shortcuts fire as backup, Slack status updates |
| **Pause/Resume** | DND and Slack status follow your session state |
| **Finish** | Bell rings, notification fires, DND deactivates, Slack clears |

### Controls

- **Left-click** ⏳ → focus panel (start, countdown, extend, end)
- **Right-click** ⏳ → context menu (settings, quit)

## Permissions

| Permission | Why | How |
|---|---|---|
| Accessibility | Toggle Do Not Disturb | System Settings → Privacy → Accessibility → Add Focally |
| Notifications | Session alerts | System Settings → Notifications → Focally → Allow |

## Focus Integration

Focally uses a layered approach to focus integration:

**1. Direct System DND (Primary)**
- Most reliable — no setup required
- Controls macOS Do Not Disturb via CFPreferences directly

**2. Signed Apple Shortcuts (Backup)**
- Pre-signed `.shortcut` files bundled with the app
- One-button install from Settings → Integrations
- Fires automatically alongside direct DND as redundancy

**3. App Intents (System-wide)**
- Exposes Start, Pause, Resume, and End Focus actions
- Available in Shortcuts app, Spotlight, and Siri
- Assign keyboard shortcuts via System Settings → Keyboard Shortcuts → App Shortcuts

## Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## Tech

SwiftUI · Observation · AppKit · App Intents · NSStatusBar · CFPreferences · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contributing

Fork → branch → PR. Keep it minimal. ✨

### Making Releases

For detailed release procedures and troubleshooting, see [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md).

## License

[MIT](LICENSE)

---
<div align="center">
Made with ⏳ by <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>

---

# 🇪🇸 Español

**Sesiones de enfoque, gestionadas.**

Una aplicación mínima para la barra de menú de macOS que maneja No Molestar, estado de Slack y temporizador — para que puedas concentrarte en lo importante.

## ¿Por qué Focally?

Revisamos todas las aplicaciones de enfoque existentes. Ninguna hacía lo que necesitábamos:

- **Apps de temporización** (Pomodone, Session) — sin DND, sin sincronización con Slack
- **Temporizadores en la barra de menú** (Thyme, Hour) — sin integración de estado
- **Suites de productividad** (RescueTime, Forest) — pesadas, costosas, con opiniones predefinidas

Focally es una sola cosa: **inicia un temporizador, entra en la zona, deja que la app maneje el resto.** Sin suscripciones, sin bloat, sin dependencia en la nube.

## Características

### Tres Modos de Enfoque

| Modo | Qué hace |
|------|----------|
| 🎯 **Tiempo de Enfoque** | Temporizador clásico (25/45/60/personalizado min) con DND + Pomodoro + sincronización con Slack |
| 📋 **Reunión** | Sesión de duración fija, mantiene DND activo, sincroniza con Slack |
| 📥 **Bandeja** | Sesión rápida de triage con configuración de sonido separada |
| ➕ **Personalizado** | Crea modos personalizados ilimitados con cualquier emoji, estado, duración y Pomodoro opcional |

### Integraciones

| Característica | Descripción |
|----------------|-------------|
| DND Directo del Sistema | Activa No Molestar de macOS vía CFPreferences — sin configuración necesaria |
| Shortcuts de Apple Firmados | Archivos `.shortcut` pre-firmados para respaldo de DND — instalación con un clic |
| App Intents | Iniciar / Pausar / Reanudar / Terminar Enfoque vía Shortcuts, Spotlight y Siri |
| Sincronización de Estado en Slack | Actualiza estado + emoji por modo de enfoque |
| Calendario de macOS | Detecta reuniones a través de EventKit sin configuración OAuth |
| Calendario → Slack + DND | Actualiza estado de Slack durante reuniones y activa DND para videollamadas |

### Características de la App

| Característica | Descripción |
|----------------|-------------|
| Sistema de sonido | Sonidos por modo (trabajo, descanso, finalización) con vista previa en vivo |
| Emoji personalizado de Slack | Renderizado de emoji del workspace con caché en disco persistente |
| Historial de sesiones | Registro completo de sesiones de enfoque pasadas con analíticas |
| Gestión de horarios | Establece bloques de enfoque recurrentes |
| Asistente de incorporación | Configuración guiada en el primer lanzamiento |
| Secretos en Keychain | Todos los tokens almacenados de forma segura en macOS Keychain |

## Instalación

### Homebrew (Recomendado)

```bash
# Agregar tap
brew tap EliabLemus/focally

# Instalar
brew install --cask focally
```

### Descarga Directa

Descarga el DMG más reciente desde [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest).

1. Abre el DMG
2. Arrastra **Focally.app** a **Aplicaciones**
3. Lanza desde la carpeta Aplicaciones (o búsqueda Spotlight)
4. Otorga permiso de Accesibilidad cuando se solicite (Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → Agregar Focally)

## Actualizaciones

### Homebrew

```bash
# Actualizar homebrew y Focally
brew update && brew upgrade --cask focally
```

**Nota**: Si Homebrew se niega a actualizar, usa:
```bash
brew reinstall --cask focally
```

### Descarga Directa

1. Descarga el DMG más reciente desde [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest)
2. Abre el DMG
3. Arrastra **Focally.app** a **Aplicaciones** (reemplaza cuando se solicite)
4. Relanza Focally

**Verificador de actualizaciones**: Focally verifica automáticamente actualizaciones cada 24 horas. Si hay una nueva versión disponible, verás un indicador de "Actualización disponible" en **Configuración → Acerca de**. Haz clic para abrir la página de descarga.

---

## Cómo funciona

| Paso | Qué sucede |
|------|------------|
| **Iniciar** | Elige un modo + actividad + duración → comienza el temporizador |
| **Enfoque** | El DND directo se activa, los shortcuts firmados se disparan como respaldo, el estado de Slack se actualiza |
| **Pausar/Reanudar** | El DND y el estado de Slack siguen el estado de tu sesión |
| **Terminar** | Suena la campana, se dispara la notificación, el DND se desactiva, Slack se limpia |

### Controles

- **Clic izquierdo** ⏳ → panel de enfoque (iniciar, cuenta regresiva, extender, terminar)
- **Clic derecho** ⏳ → menú contextual (configuración, salir)

## Permisos

| Permiso | Por qué | Cómo |
|---------|---------|-----|
| Accesibilidad | Activar No Molestar | Configuración del Sistema → Privacidad → Accesibilidad → Agregar Focally |
| Notificaciones | Alertas de sesión | Configuración del Sistema → Notificaciones → Focally → Permitir |

## Integración de Enfoque

Focally usa un enfoque por capas para la integración de enfoque:

**1. DND Directo del Sistema (Primario)**
- Más confiable — sin configuración necesaria
- Controla No Molestar de macOS vía CFPreferences directamente

**2. Shortcuts de Apple Firmados (Respaldo)**
- Archivos `.shortcut` pre-firmados incluidos con la app
- Instalación con un clic desde Configuración → Integraciones
- Se dispara automáticamente junto con el DND directo como redundancia

**3. App Intents (En todo el sistema)**
- Expone acciones de Iniciar, Pausar, Reanudar y Terminar Enfoque
- Disponible en la app de Shortcuts, Spotlight y Siri
- Asigna atajos de teclado vía Configuración del Sistema → Atajos de Teclado → Atajos de App

## Compilar desde el código fuente

Requiere Xcode 16+ y macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## Tecnología

SwiftUI · Observation · AppKit · App Intents · NSStatusBar · CFPreferences · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contribuir

Fork → branch → PR. Manténlo minimalista. ✨

### Haciendo Releases

Para procedimientos detallados de release y solución de problemas, consulta [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md).

## Licencia

[MIT](LICENSE)

---
<div align="center">
Hecho con ⏳ por <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>

---

# 🇧🇷 Português

**Sessões de foco, gerenciadas.**

Um aplicativo mínimo para a barra de menu do macOS que gerencia Não Perturbe, status do Slack e temporizador — para que você possa se concentrar no que importa.

## Por que Focally?

Analisamos todos os aplicativos de foco existentes. Nenhum fazia o que precisávamos:

- **Apps de temporização** (Pomodone, Session) — sem DND, sem sincronização com Slack
- **Temporizadores na barra de menu** (Thyme, Hour) — sem integração de status
- **Suites de produtividade** (RescueTime, Forest) — pesadas, caras, com opiniões predefinidas

Focally é uma coisa só: **inicie um temporizador, entre na zona, deixe o app cuidar do resto.** Sem assinaturas, sem inchaço, sem dependência na nuvem.

## Recursos

### Três Modos de Foco

| Modo | O que faz |
|------|-----------|
| 🎯 **Tempo de Foco** | Temporizador clássico (25/45/60/personalizado min) com DND + Pomodoro + sincronização com Slack |
| 📋 **Reunião** | Sessão de duração fixa, mantém DND ativo, sincroniza com Slack |
| 📥 **Caixa de Entrada** | Sessão rápida de triagem com configuração de som separada |
| ➕ **Personalizado** | Crie modos personalizados ilimitados com qualquer emoji, status, duração e Pomodoro opcional |

### Integrações

| Recurso | Descrição |
|---------|-----------|
| DND Direto do Sistema | Ativa Não Perturbe do macOS via CFPreferences — sem configuração necessária |
| Shortcuts da Apple Assinados | Arquivos `.shortcut` pré-assinados para backup de DND — instalação com um clique |
| App Intents | Iniciar / Pausar / Retomar / Encerrar Foco via Shortcuts, Spotlight e Siri |
| Sincronização de Status no Slack | Atualiza status + emoji por modo de foco |
| Calendário do macOS | Detecta reuniões através do EventKit sem configuração OAuth |
| Calendário → Slack + DND | Atualiza status do Slack durante reuniões e ativa DND para videochamadas |

### Recursos do App

| Recurso | Descrição |
|---------|-----------|
| Sistema de som | Sons por modo (trabalho, pausa, conclusão) com visualização ao vivo |
| Emoji personalizado do Slack | Renderização de emoji do workspace com cache em disco persistente |
| Histórico de sessões | Registro completo de sessões de foco passadas com análises |
| Gerenciamento de horários | Define blocos de foco recorrentes |
| Assistente de integração | Configuração guiada no primeiro lançamento |
| Segredos no Keychain | Todos os tokens armazenados de forma segura no macOS Keychain |

## Instalação

### Homebrew (Recomendado)

```bash
# Adicionar tap
brew tap EliabLemus/focally

# Instalar
brew install --cask focally
```

### Download Direto

Baixe o DMG mais recente de [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest).

1. Abra o DMG
2. Arraste **Focally.app** para **Aplicativos**
3. Inicie a partir da pasta Aplicativos (ou busca Spotlight)
4. Conceda permissão de Acessibilidade quando solicitado (Configurações do Sistema → Privacidade e Segurança → Acessibilidade → Adicionar Focally)

## Atualizações

### Homebrew

```bash
# Atualizar homebrew e Focally
brew update && brew upgrade --cask focally
```

**Nota**: Se o Homebrew recusar-se a atualizar, use:
```bash
brew reinstall --cask focally
```

### Download Direto

1. Baixe o DMG mais recente de [GitHub Releases](https://github.com/EliabLemus/focally/releases/latest)
2. Abra o DMG
3. Arraste **Focally.app** para **Aplicativos** (substitua quando solicitado)
4. Reinicie o Focally

**Verificador de atualizações**: O Focally verifica automaticamente atualizações a cada 24 horas. Se uma nova versão estiver disponível, você verá um indicador de "Atualização disponível" em **Configurações → Sobre**. Clique para abrir a página de download.

---

## Como funciona

| Passo | O que acontece |
|-------|----------------|
| **Iniciar** | Escolha um modo + atividade + duração → o temporizador começa |
| **Foco** | O DND direto é ativado, os shortcuts assinados são disparados como backup, o status do Slack é atualizado |
| **Pausar/Retomar** | O DND e o status do Slack seguem o estado da sua sessão |
| **Concluir** | O sino toca, a notificação é disparada, o DND é desativado, o Slack é limpo |

### Controles

- **Clique esquerdo** ⏳ → painel de foco (iniciar, contagem regressiva, estender, encerrar)
- **Clique direito** ⏳ → menu contextual (configurações, sair)

## Permissões

| Permissão | Por que | Como |
|-----------|---------|-----|
| Acessibilidade | Ativar Não Perturbe | Configurações do Sistema → Privacidade → Acessibilidade → Adicionar Focally |
| Notificações | Alertas de sessão | Configurações do Sistema → Notificações → Focally → Permitir |

## Integração de Foco

O Focally usa uma abordagem em camadas para a integração de foco:

**1. DND Direto do Sistema (Primário)**
- Mais confiável — sem configuração necessária
- Controla Não Perturbe do macOS via CFPreferences diretamente

**2. Shortcuts da Apple Assinados (Backup)**
- Arquivos `.shortcut` pré-assinados incluídos com o app
- Instalação com um clique a partir de Configurações → Integrações
- Dispara automaticamente junto com o DND direto como redundância

**3. App Intents (Em todo o sistema)**
- Expõe ações de Iniciar, Pausar, Retomar e Encerrar Foco
- Disponível no app de Shortcuts, Spotlight e Siri
- Atribua atalhos de teclado via Configurações do Sistema → Atalhos de Teclado → Atalhos de App

## Compilar a partir do código-fonte

Requer Xcode 16+ e macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## Tecnologia

SwiftUI · Observation · AppKit · App Intents · NSStatusBar · CFPreferences · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contribuir

Fork → branch → PR. Mantenha minimalista. ✨

### Fazendo Releases

Para procedimentos detalhados de release e solução de problemas, consulte [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md).

## Licença

[MIT](LICENSE)

---
<div align="center">
Feito com ⏳ por <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>