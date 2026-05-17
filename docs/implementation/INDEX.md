# Implementation

Dominio de implementación técnica de Focally.

---

## Archivos

- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** — Guía de testing (unit, UI, e2e)
- **[DEBUGGING_GUIDE.md](DEBUGGING_GUIDE.md)** — Cómo debuggear problemas comunes
- **[CI_CD.md](CI_CD.md)** — Configuración de CI/CD en GitHub Actions
- **[PERFORMANCE.md](PERFORMANCE.md)** — Optimizaciones de rendimiento

---

## Principios

1. **Type safety explícita** — Closures con type hints para CI
2. **Weak self en closures** — Evitar retain cycles
3. **No dependencies externas** — Solo frameworks nativos
4. **Tests first** — SDD + TDD donde sea posible