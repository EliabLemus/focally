# SPEC_FOCUS_INTEGRATION_FINAL_DECISION.md

## Decisión final

**Objetivo de producto**
- Al dar `Start Session` o `Pomodoro Start`, Focally debe activar el **Do Not Disturb / Focus de Apple**.
- Al terminar, cancelar o resetear la sesión, Focally debe **desactivarlo** para que vuelvan a entrar notificaciones.
- La experiencia ideal es **cero setup manual del usuario**.

## Respuesta técnica final

### Lo que sí está confirmado
1. **Apple Shortcuts sí tiene una acción nativa `Set Focus`.**
   - Esto permite crear shortcuts que activen/desactiven un Focus del sistema.
2. **Apple App Shortcuts sí permite exponer acciones propias de la app sin setup manual.**
   - Apple lo documenta como `no user setup required`.
   - Esto sirve para exponer acciones de Focally en Shortcuts, Spotlight y Siri.
3. **El repo actual de Focally no usa App Intents / App Shortcuts.**
   - La implementación actual solo ejecuta `/usr/bin/shortcuts run <name>`.
   - Eso depende de que existan shortcuts creados previamente.

### Lo que NO quedó demostrado por vía pública/soportada
1. **No encontré evidencia suficiente de una API pública directa para que Focally active `Work Focus` o `Do Not Disturb` del sistema desde código Swift sin un shortcut puente.**
2. **No encontré un mecanismo oficial claro para que Focally componga e instale automáticamente un shortcut de Apple que use `Set Focus`, sin intervención del usuario.**
3. **Los proyectos de terceros revisados no prueban una ruta segura para shipping.**
   - Ej.: `focusctl` parece apoyarse en archivos `.shortcut`, defaults y notificaciones con apariencia de hack/ingeniería inversa, no en una ruta pública clara y confiable para una feature principal.

## Conclusión ejecutiva

### Conclusión 1 — TASK-037 no cumple el objetivo principal
TASK-037 implementó un puente por nombre de shortcut. Eso es válido como MVP exploratorio, pero **no cumple** el objetivo real de:
- activar Apple DND/Focus automáticamente
- con cero setup manual
- de forma soportada y confiable

### Conclusión 2 — Hay que separar dos promesas distintas
- **Promesa A: acciones de Focally disponibles sin setup manual** → **Sí** se puede con `AppShortcutsProvider`.
- **Promesa B: encender/apagar Apple Focus del sistema sin setup manual y sin hacks** → **No está probada** con evidencia pública suficiente.

### Conclusión 3 — El objetivo de producto sigue siendo correcto
El objetivo no cambia:
- `Start Session` debe encender Focus/DND del sistema
- `Stop/End/Reset` debe apagarlo

Lo que cambia es la honestidad técnica:
- hoy **no hay base suficiente** para prometer ese comportamiento por vía pública y cero-setup
- el camino actual de `shortcuts run "Focally Start Focus"` **no resuelve** esa brecha

## Decisión recomendada

### Decisión principal
**Despromover el camino actual de shortcut manual como solución final.**

### Decisión de arquitectura
Adoptar una arquitectura en 3 capas:

1. **App Shortcuts nativos de Focally**
   - Exponer acciones propias de Focally automáticamente vía `AppIntents`.
   - Esto sí cumple `no user setup required`.

2. **Focus System Bridge (capability layer)**
   - Encapsular cualquier intento de activar Focus del sistema detrás de una capa explícita.
   - Esta capa debe distinguir entre:
     - `unsupported-public-api`
     - `manual-shortcut-bridge`
     - `legacy-dnd-fallback`

3. **Legacy DND fallback**
   - Mantenerlo como camino operativo real mientras no exista una ruta pública clara para Apple Focus system toggle sin setup manual.

## Implicación práctica para v0.6.6+

### No se debe seguir afirmando
- que Focally ya resuelve Apple Focus nativo de forma automática y sin setup

### Sí se puede afirmar
- que Focally ya tiene:
  - estado local visible
  - fallback legacy
  - base para App Shortcuts de la app
  - base para una futura integración nativa mejor resuelta

## Qué significa para la siguiente tarea
La siguiente tarea no debe seguir intentando “hacer pasar” el shortcut manual como solución definitiva.

Debe:
1. corregir la arquitectura para que sea honesta
2. agregar `AppIntents + AppShortcutsProvider`
3. aislar claramente el bridge al Focus del sistema
4. mantener el objetivo del producto visible como target, pero sin fingir que ya existe una vía pública suficiente
