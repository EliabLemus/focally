# UX Krug Improvements - Implementation Plan

**Date:** 2026-05-26
**Skills used:** `ui-no-pensar` + `focally-ui-audit`

---

## Overview

Implementación de 8 fixes de UX basados en frameworks de Steve Krug ("Don't Make Me Think") para mejorar la usabilidad de Focally.

**Priority Order:**
1. **Critical:** SPEC-001, SPEC-002 (2 fixes)
2. **High:** SPEC-003, SPEC-004, SPEC-005 (3 fixes)
3. **Medium:** SPEC-006, SPEC-007 (2 fixes)
4. **Low:** SPEC-008 (1 fix)

---

## Phase 1: Critical Fixes (Immediate)

### SPEC-001: Simplificar "Paused · Notifications are back"
- **File:** `MenuBarDropdownView.swift:99`
- **Change:** Line 99 simplified
- **Risk:** Very low - single line change
- **Dependencies:** None
- **Estimated time:** 5 min

### SPEC-002: Agregar hover state a PredefinedTaskQuickButton
- **File:** `FocusSessionComponents.swift:345-377`
- **Change:** Add `@State isHovering`, hover animation, border, chevron
- **Risk:** Low - isolated component
- **Dependencies:** None
- **Estimated time:** 15 min

---

## Phase 2: High Priority Fixes

### SPEC-003: Eliminar "Create presets from Task Configuration."
- **File:** `MenuBarDropdownView.swift:75`
- **Change:** Simplify empty state text
- **Risk:** Very low - single line change
- **Dependencies:** None
- **Estimated time:** 5 min

### SPEC-004: Eliminar redundancia en footer
- **File:** `MenuBarDropdownView.swift:203`
- **Change:** Remove timer state from footer, keep only DND
- **Risk:** Low - conditional logic already in place
- **Dependencies:** SPEC-001 (should implement after)
- **Estimated time:** 10 min

### SPEC-005: Simplificar "Quiet mode on" vs "Quiet mode ready"
- **File:** `MenuBarDropdownView.swift:203`
- **Change:** Simplify to "DND Active" / "DND Off"
- **Risk:** Low - single line change
- **Dependencies:** SPEC-004 (implement together)
- **Estimated time:** 5 min

---

## Phase 3: Medium Priority Fixes

### SPEC-006: Mejorar header "Start fast, stay quiet."
- **File:** `MenuBarDropdownView.swift:42-56`
- **Change:** Remove or replace subtitle
- **Risk:** Low - visual only change
- **Dependencies:** None
- **Estimated time:** 10 min

### SPEC-007: Clarificar "Predefined tasks" → "Your Presets"
- **File:** `MenuBarDropdownView.swift:65`
- **Change:** Rename section header
- **Risk:** Very low - single line change
- **Dependencies:** None
- **Estimated time:** 5 min

---

## Phase 4: Low Priority Fix

### SPEC-008: Eliminar "live" en "Notifications live"
- **File:** `MenuBarDropdownView.swift:108`
- **Change:** Remove word "live" or entire text
- **Risk:** Low - visual only change
- **Dependencies:** SPEC-001 (may be redundant if SPEC-001 removes paused badge entirely)
- **Estimated time:** 5 min

---

## Execution Strategy

### Batch 1: Critical (SPEC-001 + SPEC-002)
```
Total estimated time: 20 min
Risk: Low
Files modified: 2
```

### Batch 2: High (SPEC-003 + SPEC-004 + SPEC-005)
```
Total estimated time: 20 min
Risk: Low
Files modified: 2
Dependencies: SPEC-001
```

### Batch 3: Medium (SPEC-006 + SPEC-007)
```
Total estimated time: 15 min
Risk: Low
Files modified: 2
```

### Batch 4: Low (SPEC-008)
```
Total estimated time: 5 min
Risk: Low
Files modified: 1
Dependencies: SPEC-001
```

---

## Testing Strategy

After each batch:
1. Build and run Focally
2. Test all affected flows
3. Verify acceptance criteria for each spec
4. Check for regressions
5. Test in light and dark modes

---

## Auto-Review

After implementation of each batch:
```bash
cd ~/projects/focally
./scripts/pr-auto-review.sh review --fix
```

---

## Rollback Plan

If any batch causes issues:
```bash
git revert <commit-hash>
```

All changes are atomic and isolated, making rollback straightforward.

---

## Success Metrics

- [ ] All Critical fixes implemented and tested
- [ ] All High fixes implemented and tested
- [ ] All Medium fixes implemented and tested
- [ ] All Low fixes implemented and tested
- [ ] No regressions in existing functionality
- [ ] Auto-review passes
- [ ] UI-AUDIT.md updated with "RESOLVED" status

---

## Next Steps

1. ✅ All specs created
2. ⏳ Implement Batch 1 (Critical)
3. ⏳ Implement Batch 2 (High)
4. ⏳ Implement Batch 3 (Medium)
5. ⏳ Implement Batch 4 (Low)
6. ⏳ Update UI-AUDIT.md with resolutions