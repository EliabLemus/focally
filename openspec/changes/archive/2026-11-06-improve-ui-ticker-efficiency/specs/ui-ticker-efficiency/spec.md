# Delta spec: ui-ticker-efficiency

## ADDED Requirements

### Requirement: El ticker de UI usa tolerance y deriva el valor del reloj

El timer de actualización de UI SHALL tener `tolerance` ≥ 0.1s y SHALL derivar el tiempo mostrado de `Date` (reconciliación por reloj), no del conteo de ticks.

#### Scenario: Título correcto tras sleep

- **WHEN** la Mac duerme 5 minutos con un pomodoro activo y despierta
- **THEN** el primer tick posterior muestra el tiempo correcto derivado de la fecha objetivo (sin esperar N ticks para recorrer la diferencia)

#### Scenario: Tolerance aplicado

- **WHEN** se crea el timer de UI
- **THEN** `timer.tolerance` es ≥ 0.1 y el primer fire está anclado al siguiente segundo de pared

### Requirement: El status item solo se actualiza cuando el string cambia

La asignación del título del status item SHALL ocurrir únicamente cuando el string formateado difiere del asignado previamente.

#### Scenario: Ticks sin cambio visible

- **WHEN** dos ticks consecutivos producen el mismo string (p. ej. vista sin sesión activa)
- **THEN** no se reasigna `button.title` ni se dispara re-layout de AppKit
