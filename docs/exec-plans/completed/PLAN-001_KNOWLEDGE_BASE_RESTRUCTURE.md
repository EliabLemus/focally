# PLAN-001: Reestructuración de Knowledge Base

## Estado
✅ completed

## Objetivo
Transformar la documentación monolítica de Focally en una knowledge base estructurada siguiendo el enfoque de OpenAI ("el repositorio es el sistema de registro").

## Pasos
1. ✅ Crear estructura de directorios `docs/` con dominios claros
2. ✅ Crear `docs/KNOWLEDGE_BASE.md` como índice principal
3. ✅ Crear `docs/architecture/` para arquitectura
4. ✅ Crear `docs/design/` para design system
5. ✅ Crear `docs/implementation/` para guías técnicas
6. ✅ Crear `docs/exec-plans/` para planes de ejecución
7. ✅ Crear `docs/product-specs/` para specs de producto
8. ✅ Crear `docs/references/` para referencias externas
9. ✅ Crear `docs/guides/` para guías operativas
10. ✅ Mover archivos existentes a sus nuevas ubicaciones
11. ✅ Crear `docs/architecture/ARCHITECTURE.md` con mapa de dominios
12. ✅ Crear `docs/architecture/LAYER_RULES.md` con invariantes
13. ✅ Crear `docs/exec-plans/TECH_DEBT_TRACKER.md`
14. ⏳ Actualizar AGENTS.md para que sea un índice (~100 líneas)

## Criterios de Aceptación
- [x] Estructura de directorios creada
- [x] Archivos existentes migrados
- [x] ARCHITECTURE.md con mapa de dominios claro
- [x] LAYER_RULES.md con invariantes mecánicas
- [x] TECH_DEBT_TRACKER.md inicializado
- [ ] AGENTS.md reducido a ~100 líneas como índice
- [ ] Todos los archivos de docs tienen INDEX.md

## Notas
Basado en el artículo de OpenAI "Engineering Systems: Codex in an Agent-Centered World". La clave es darle al agente un mapa, no un manual gigante.

## Fecha de Creación
2026-05-16

## Fecha de Completado
2026-05-16 (pasos 1-13), paso 14 pendiente