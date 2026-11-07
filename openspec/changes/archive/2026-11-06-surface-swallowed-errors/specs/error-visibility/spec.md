# Delta spec: error-visibility

## ADDED Requirements

### Requirement: Ningún fallo de persistencia es silencioso

Todo catch de error de E/S o de decodificación en servicios de persistencia SHALL loguear el error subyacente con el wrapper `Logger` y la categoría del servicio antes de continuar o recuperarse.

#### Scenario: Disco lleno al guardar sesión

- **WHEN** guardar la sesión activa falla por E/S
- **THEN** el error aparece en unified logging con la categoría del servicio y la sesión en memoria sigue viva (best-effort sin crash)

#### Scenario: JSON de sesión corrupto

- **WHEN** cargar la sesión falla por decodificación
- **THEN** el archivo corrupto se renombra a `.corrupt-<timestamp>`, se loguea el error y el app arranca con estado limpio en lugar de fallar en cada lanzamiento

### Requirement: El silencio debe estar justificado

Todo `try?` que permanezca tras el cambio SHALL tener un comentario que justifique por qué el silencio es seguro (requisito de auditoría del change; no aplica a los convertidos a catch con log).

#### Scenario: Auditoría completa

- **WHEN** se grep `try?` en `Sources/Focally/` al cerrar el change
- **THEN** cada ocurrencia restante tiene comentario de justificación o el archivo tiene nota en el STATUS del change
