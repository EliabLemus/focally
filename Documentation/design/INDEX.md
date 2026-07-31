# Design

Dominio de diseño de Focally.

---

## Archivos

- **[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)** — Design system completo (colores, tipografía, espaciado)
- **[COLOR_TOKENS.md](COLOR_TOKENS.md)** — Referencia de tokens de color (light/dark)
- **[COMPONENTS.md](COMPONENTS.md)** — Componentes reutilizables y patrones
- **[DARK_MODE.md](DARK_MODE.md)** — Implementación de dark mode

---

## Principios

1. **Modern Corporate Minimalism** — Claridad > Decoración
2. **Proximidad > Líneas** — Agrupar por cercanía espacial
3. **Profundidad tonal > Sombras pesadas** — Capas de color + blur
4. **Consistencia > Creatividad** — Seguir convenciones de macOS
5. **Quiet Confidence** — UI competente sin ruido

---

## Reglas Clave

- **NUNCA** hardcodear colores — usar `Color.focallyXxx`
- **NUNCA** usar shorthand `.focallyXxx` — siempre `Color.focallyXxx`
- **NUNCA** usar Material Design Icons — SF Symbols exclusivamente
- **NUNCA** usar APIs de iOS — macOS only