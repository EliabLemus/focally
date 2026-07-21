# Spec: Fuzzy Emoji Search

## Objetivo
Reemplazar el substring match (`contains`) en `EmojiValidator.searchShortcodes` con fuzzy matching para que escribir `:brin` encuentre `:brain:`, `:taco` encuentre `:taco_bell:`, etc.

## Cambios

### 1. Agregar fuzzy matcher nativo en Swift
Crear función `fuzzyMatch(pattern:target:) -> (matched: Bool, score: Int)` en `EmojiValidator`:
- Algoritmo: **subsequence matching** con scoring por agrupación
- `:brin` vs `brain` → b→b, r→r, a→i(salta), i→n(salta), n→(no hay) → NO match
- `:bran` vs `brain` → b→b, r→r, a→a, n→i(salta)... hmm

Mejor: **fuzzy substring** — el patrón debe aparecer como subsecuencia en el target, pero permitiendo 1 error (inserción/deleción)

Scoring:
- Char consecutivo sin gap: +3
- Char consecutivo con 1 gap: +1
- Inicio de palabra bonus: +2 (split por `_` o `-`)
- Prefijo exacto bonus: +5

### 2. Actualizar `searchShortcodes`
- Reemplazar `stripped.contains(lowerQuery)` con llamada al fuzzy matcher
- Mantener el sorting por score (mayor score primero)
- Mantener prefijos primero como antes
- Mantener límite de 20 resultados

### 3. UI: activar search al tipo sin depender de `:` inicial
- Actualmente el `showEmojiPicker` solo se activa cuando el emoji es exactamente `:`
- Cambiar: si el texto contiene `:` al final (o es solo `:`), activar búsqueda con lo que sigue
- `:bra` → busca "bra"
- `:b` → busca "b"

## Archivos
- `Focally/Services/SlackService.swift` — `searchShortcodes` + nueva función fuzzy
- `Focally/Views/Timer/FocusModeEditSheet.swift` — activar search con partial `:` suffix

## No hacer
- No agregar dependencias externas
- No cambiar la UI visual del grid de sugerencias
- No cambiar el preview del emoji seleccionado
