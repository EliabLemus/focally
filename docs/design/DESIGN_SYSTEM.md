# DESIGN.md — Focally Design System Reference

> **Fuente original**: Diseño basado en *Stitch by Google* — "Focused Precision" (light) + "Obsidian Flux" (dark)
> **Creado**: 2026-05-01 — v0.6.0 UI Redesign
> **Última actualización**: 2026-05-01

---

## Filosofía

**Modern Corporate Minimalism** con influencias **Glassmorphic** estilo macOS.

La personalidad de marca es disciplinada, silenciosa y de alto rendimiento. La UI debe evocar calma y utilidad instrumental — menos como software, más como una herramienta finamente afinada. Prioriza claridad sobre decoración, usa whitespace generoso y profundidad sutil para organizar información. El objetivo principal es reducir carga cognitiva.

### Principios

1. **Claridad > Decoración** — Si un elemento no ayuda al usuario a entender o actuar, quítalo
2. **Proximidad > Líneas** — Agrupa elementos por cercanía espacial, no con borders
3. **Profundidad tonal > Sombras pesadas** — Usa capas de color y blur, no drop shadows
4. **Consistencia > Creatividad** — Sigue las convenciones de macOS; no reinventes ruedas
5. **Quiet Confidence** — La UI debe sentirse competente sin ser ruidosa

---

## Paleta de Colores

### Light Theme — "Focused Precision"

| Token | Hex | Uso |
|-------|-----|-----|
| `focallyBackground` | `#f9f9f9` | Window/main canvas background |
| `focallySurface` | `#f9f9f9` | Sidebar/toolbar surface |
| `focallySurfaceContainerLowest` | `#ffffff` | Cards, elevated surfaces |
| `focallySurfaceContainerLow` | `#f3f3f4` | Inputs, subtle containers |
| `focallySurfaceContainer` | `#eeeeee` | Mid-elevation containers |
| `focallySurfaceContainerHigh` | `#e8e8e8` | Active sidebar items |
| `focallySurfaceContainerHighest` | `#e2e2e2` | Hover states |
| `focallyPrimary` | `#0058bc` | Primary actions, active states, selection |
| `focallyOnPrimary` | `#ffffff` | Text on primary surfaces |
| `focallySecondary` | `#5e5e5e` | Secondary actions |
| `focallyTertiary` | `#9e3d00` | Accent (success indicators, charts) |
| `focallyTertiaryContainer` | `#c64f00` | Tertiary backgrounds |
| `focallyOnSurface` | `#1a1c1c` | Primary text |
| `focallyOnSurfaceVariant` | `#414755` | Secondary text |
| `focallyOutline` | `#717786` | Tertiary text, disabled text |
| `focallyOutlineVariant` | `#c1c6d7` | Borders, dividers (10% opacity) |
| `focallyCardBorder` | `#00000010` | Card borders (rgba black 10%) |
| `focallyError` | `#ba1a1a` | Error states |
| `focallyErrorContainer` | `#ffdad6` | Error backgrounds |
| `focallyInverseSurface` | `#2f3131` | Inverted surfaces |
| `focallyInverseOnSurface` | `#f0f1f1` | Text on inverted surfaces |

### Dark Theme — "Obsidian Flux"

| Token | Hex | Uso |
|-------|-----|-----|
| `focallyBackground` | `#121317` | Window/main canvas background |
| `focallySurface` | `#121317` | Sidebar/toolbar surface |
| `focallySurfaceContainerLowest` | `#0d0e12` | Deepest elevation |
| `focallySurfaceContainerLow` | `#1a1b1f` | Cards, elevated surfaces |
| `focallySurfaceContainer` | `#1e1f23` | Mid-elevation containers |
| `focallySurfaceContainerHigh` | `#292a2e` | Active sidebar items |
| `focallySurfaceContainerHighest` | `#343539` | Hover states |
| `focallyPrimary` | `#adc6ff` | Primary actions, active states |
| `focallyOnPrimary` | `#002e69` | Text on primary surfaces |
| `focallySecondary` | `#c8c6c8` | Secondary actions |
| `focallyTertiary` | `#c8c6c8` | Accent indicators |
| `focallyTertiaryContainer` | `#919092` | Tertiary backgrounds |
| `focallyOnSurface` | `#e3e2e7` | Primary text |
| `focallyOnSurfaceVariant` | `#c1c6d7` | Secondary text |
| `focallyOutline` | `#8b90a0` | Tertiary text, disabled text |
| `focallyOutlineVariant` | `#414755` | Borders, dividers |
| `focallyCardBorder` | `#ffffff14` | Card borders (rgba white 8%) |
| `focallyError` | `#ffb4ab` | Error states |
| `focallyErrorContainer` | `#93000a` | Error backgrounds |

### Reglas de Color

- **NUNCA** usar colores hardcodeados. Siempre usar `Color.focallyXxx`
- **NUNCA** usar shorthand `.focallyXxx` como ShapeStyle — siempre `Color.focallyXxx` (el compilador Swift no lo resuelve en muchos contextos)
- El primary blue (#0058bc light / #adc6ff dark) se usa **escasamente** — solo para acciones primarias, estados activos e indicadores de selección
- Superficies usan la jerarquía de `surfaceContainer*` para indicar elevación
- Texto usa `onSurface` → `onSurfaceVariant` → `outline` para la jerarquía visual
- Bordes y divisores usan `cardBorder` o `outlineVariant` con baja opacidad

---

## Tipografía

**Fuente principal**: Inter (bundled en `Focally/Resources/Fonts/`)
**Fallback**: System default (San Francisco)

### Escala Tipográfica

| Rol | Tamaño | Peso | Line Height | Letter Spacing | Uso |
|-----|--------|------|-------------|----------------|-----|
| `.focallyDisplay` | 28px | SemiBold (600) | 34px | -0.02em | Page titles |
| `.focallyH1` | 22px | SemiBold (600) | 28px | -0.01em | Section titles |
| `.focallyH2` | 17px | SemiBold (600) | 22px | -0.01em | Subsection headers |
| `.focallyBody` | 13px | Regular (400) | 20px | 0em | Body text |
| `.focallyBodyBold` | 13px | SemiBold (600) | 20px | 0em | Emphasized body |
| `.focallyCaption` | 11px | Medium (500) | 14px | 0.01em | Metadata, labels |
| `.focallyMicro` | 10px | Medium (500) | 12px | 0em | Tiny labels, footnotes |
| `.focallyButton` | 13px | Medium (500) | 16px | 0em | Button text |

### Reglas Tipográficas

- Body text a 13px es el estándar macOS para legibilidad en productividad
- Los headings se distinguen por **peso** (SemiBold), no por tamaño masivo
- Negative letter-spacing en headings para look tight "Apple-esque"
- Labels/captions pueden usar uppercase + tracking amplio para diferenciar metadata
- **NUNCA** usar `.tracking(.widest)` — no existe en SwiftUI. Usar `.tracking(1.5)`

---

## Espaciado

Grid base: **4px**. Todo espacio es múltiplo de 4.

| Token | Valor | Uso |
|-------|-------|-----|
| `FocallySpacing.xs` | 4px | Tight spacing, icon gaps |
| `FocallySpacing.sm` | 8px | Related items, inner padding |
| `FocallySpacing.md` | 16px | Standard padding, comfortable spacing |
| `FocallySpacing.lg` | 24px | Section breaks, page margins |
| `FocallySpacing.xl` | 40px | Generous margins, page-level breathing room |
| `FocallySpacing.gutter` | 20px | Grid gutters between bento cards |
| Sidebar width | 260px | Fixed navigation sidebar |

### Reglas de Espaciado

- Agrupar elementos relacionados con 8px
- Separar secciones distintas con 24px+
- Padding dentro de containers: 16px–24px (nunca menos)
- Margen horizontal de página: 24px
- **Nunca** apretar elementos — mejor whitespace generoso que UI cramped

---

## Radius (Esquinas)

| Token | Valor | Uso |
|-------|-------|-----|
| `FocallyRadius.sm` | 4px | Checkboxes, radios, tiny elements |
| `FocallyRadius.default` | 8px | Buttons, inputs, standard components |
| `FocallyRadius.md` | 12px | Larger buttons, medium containers |
| `FocallyRadius.lg` | 16px | Cards, panels, main containers |
| `FocallyRadius.xl` | 24px | Hero elements, featured cards |
| `FocallyRadius.full` | 9999px | Pills, avatars |

### Reglas de Radius

- Input fields y buttons estándar: 8px (default)
- Cards y paneles principales: 16px (lg)
- Selección indicators en sidebar: 6px, nunca tocan el borde del container (mantener 4–6px margin)
- CTAs de alta prioridad pueden usar pill shape (full) para romper el ritmo del grid

---

## Elevación y Profundidad

La profundidad se comunica con **capas tonales** y **backdrop blur**, no sombras pesadas.

### Niveles de Elevación

| Nivel | Light | Dark | Blur | Borde |
|-------|-------|------|------|-------|
| **Base** (L0) | `#f9f9f9` bg | `#121317` bg | Ninguno | Ninguno |
| **Sidebar/Toolbar** (L1) | 80% opacity + blur 30px | 80% opacity + blur 30px | 20–30px | Inner 0.5px white 10% |
| **Main Canvas** (L2) | `#ffffff` solid | `#1a1b1f` solid | Ninguno | Ninguno |
| **Popovers/Modals** (L3) | `#ffffff` + blur | `#2c2c2e` + blur | 20–30px | Inner 0.5px white 10% |
| **Floating** (L4) | Shadow diffused | Shadow diffused | Ninguno | 0 10px 30px rgba(0,0,0,0.1) |

### Glass Effect

Para sidebar y popovers, usar `.ultraThinMaterial` o `.background(.ultraThinMaterial)`.

Bordes glass: `0.5px` inner stroke, `white.opacity(0.1)`.

---

## Layout

### Arquitectura

- **Sidebar fija**: 260px, navigation con tabs verticales
- **Canvas fluid**: Expande al espacio disponible
- **Max-width para contenido denso**: ~900px centrado
- **Bento grid**: 12-columnas para cards (ej: 8+4, 7+5)

### Navegación

- Tabs verticales en sidebar con icon + label
- Active tab: `focallySurfaceContainerHigh` background
- Hover: `focallySurfaceContainerHighest` background
- TopBar: 48px, ViewBuilder para contenido izquierdo, buttons a la derecha

---

## Componentes

### Botones

| Tipo | Estilo |
|------|--------|
| **Primary** | `focallyPrimary` bg, white text, 8px radius |
| **Secondary** | `focallySurfaceContainerHighest` bg, `onSurface` text |
| **Ghost** | Transparent, icon-only, bg on hover |
| **Pill** | Full radius, primary o secondary style |

Ver `FocallyPillButton` en `SharedComponents.swift`.

### Cards

Usar SIEMPRE el modifier `.focallyCard()` — maneja automáticamente:
- Background (surface container + theme adaptive)
- Border (1px soft gray light / rgba white dark)
- Shadow (light) vs border (dark)
- Radius (16px)

### Toggle

`FocallyToggleButton` — toggle switch estilizado. **NUNCA** usar `.toggleStyle(FocallyToggleButtonStyle())` — esa API no existe. Usar `.toggleStyle(.switch)` para el system toggle, o `FocallyToggleButton` directamente.

### Segmented Control

`FocallySegmentedControl(selection:options:)` — track recessed con sliding tile blanco.

### Inputs

- Background: `focallySurfaceContainerLow`
- Border: Ninguna en estado default
- Focus: 2px ring `focallyPrimary` al 50% opacidad
- Radius: 8px (default)
- Padding: 16px horizontal, 12px vertical
- **NUNCA** usar `.keyboardType()` — es iOS-only

### Progress Indicators

- Track: 4px height, `focallySurfaceContainerLow` background
- Fill: `focallyPrimary` o `focallyTertiary`
- Radius: 2px (fully rounded)

### Badges/Chips

- Pill shape (full radius)
- Active: `focallyPrimary` bg, white text
- Inactive: `focallySurfaceContainerHighest` bg, `focallyOnSurfaceVariant` text
- Height: 24–32px

### Star Ratings

- Filled: `focallyPrimary`
- Empty: `focallyOutline.opacity(0.3)`

---

## Iconografía

- **SF Symbols** — Iconos nativos de macOS (no Material Symbols)
- Tamaño estándar: 16–20px
- Contenedores de icono: 40×40px, `focallySurfaceContainerLowest` bg, 12px radius
- Color: `focallyPrimary` para activos, `focallyOutline` para inactivos

---

## Responsive / Bento Grid

El layout usa un sistema de **bento grid** de 12 columnas con gutters de 20px.

| Layout | Columnas |
|--------|----------|
| 2 columnas iguales | 6 + 6 |
| Score grande + métrica | 8 + 4 |
| Chart + lista | 7 + 5 |
| Full width | 12 |

---

## Dark Mode

Dark mode se implementa vía **Asset Catalog** con variantes light/dark. No hay lógica condicional en código.

### Reglas Dark Mode

- Todas las vistas DEBEN usar `Color.focallyXxx` — nunca colores hardcodeados
- El Asset Catalog resuelve automáticamente light/dark
- Cards usan `.focallyCard()` que cambia shadow (light) a border (dark)
- Glass effects usan `.ultraThinMaterial` — adapta automáticamente
- Texto en dark: `onSurface` (#e3e2e7) es el blanco principal, nunca white puro
- Shadows en dark: más diffusas, mayor blur, menor opacidad

---

## Lo que NO hacemos

Estas son decisiones explícitas de diseño que NO deben reintroducirse:

- ❌ **Energy Level cards** — No incluidas en el redesign
- ❌ **Music cards** — No incluidas en el redesign
- ❌ **Colores hardcodeados** — Siempre usar tokens del design system
- ❌ **Shorthand `.focallyXxx`** — Siempre `Color.focallyXxx`
- ❌ **Heavy drop shadows** — Tonales + blur, no sombras tradicionales
- ❌ **Hard borders** — Soft borders o ninguna border
- ❌ **iOS APIs** — `.keyboardType()`, `.navigationTitle()`, etc.
- ❌ **External dependencies** — Solo SwiftUI + system frameworks
- ❌ **Material Design Icons** — SF Symbols exclusivamente

---

## Archivos del Design System

| Archivo | Contenido |
|---------|-----------|
| `Focally/DesignSystem/FocallyColors.swift` | 44 color tokens con hex fallback |
| `Focally/DesignSystem/FocallyTypography.swift` | 8 roles tipográficos |
| `Focally/DesignSystem/FocallySpacing.swift` | Spacing constants (4px grid) |
| `Focally/DesignSystem/FocallyRadius.swift` | Corner radius constants |
| `Focally/DesignSystem/FocallyTheme.swift` | Theme environment, glass effects |
| `Focally/DesignSystem/CardModifier.swift` | `.focallyCard()` modifier |
| `Focally/Assets.xcassets/` | 21 color sets con light/dark variants |
| `Focally/Resources/Fonts/` | Inter Regular, Medium, SemiBold, Bold |

---

## Checklist para nuevas vistas/features

Antes de agregar cualquier nueva vista o componente, verificar:

- [ ] Usa `Color.focallyXxx` (nunca shorthand ni hardcode)
- [ ] Usa `.focallyCard()` para cards (nunca shadow/border manual)
- [ ] Usa roles tipográficos del sistema (`.focallyH2`, `.focallyBody`, etc.)
- [ ] Usa `FocallySpacing.*` para padding/margins
- [ ] Usa `FocallyRadius.*` para corner radius
- [ ] Usa SF Symbols (no Material Icons)
- [ ] Funciona en light AND dark (gracias a Asset Catalog)
- [ ] No usa APIs de iOS
- [ ] No agrega dependencias externas
- [ ] Sigue el bento grid de 12 columnas cuando aplica
- [ ] Respeta la jerarquía de elevación (base → sidebar → canvas → popover)
