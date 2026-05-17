# Architecture

Dominio de arquitectura de Focally.

---

## Archivos

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Mapa de alto nivel de dominios y organización de capas
- **[LAYER_RULES.md](LAYER_RULES.md)** — Reglas de dependencia entre capas (invariantes)
- **[SERVICE_PATTERN.md](SERVICE_PATTERN.md)** — Patrón de servicios y singletons
- **[STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)** — State management con SwiftUI

---

## Principios

1. **Dependencias solo hacia adelante** → Models → Services → ViewModels → Views
2. **Cross-cutting concerns** → Providers único punto de entrada
3. **Single source of truth** → Services como ObservableObject singletons
4. **Environment values** → Para temas, accesibilidad, settings