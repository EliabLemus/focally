# Delta spec: calendar-sync-debounce

## ADDED Requirements

### Requirement: Las ráfagas de EKEventStoreChanged coalescen en un solo refetch

El handler de cambios del event store SHALL aplicar debounce (~2s, intervalo inyectable) de modo que N notificaciones dentro de la ventana produzcan exactamente un refetch al expirar.

#### Scenario: Ráfaga de notificaciones

- **WHEN** llegan 5 notificaciones `EKEventStoreChanged` en 500ms
- **THEN** el servicio ejecuta exactamente 1 refetch, ~2s después de la última notificación

#### Scenario: Cambio aislado

- **WHEN** llega 1 notificación y no hay más en la ventana
- **THEN** el refetch ocurre ~2s después, igual que hoy en comportamiento observable
