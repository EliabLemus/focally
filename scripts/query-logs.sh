#!/bin/bash

# Script para query logs de Focally estilo LogQL
# Basado en docs/exec-plans/active/PLAN-004_OBSERVABILITY.md

set -e

SUBSYSTEM="app.focally.mac"

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <query> [opciones]"
    echo ""
    echo "Queries soportados:"
    echo "  all                     - Todos los logs"
    echo "  level:<level>           - Filtrar por nivel (debug, info, warning, error, fault)"
    echo "  category:<category>     - Filtrar por categoría (App, Calendar, Timer, Slack, DND, Analytics, UI)"
    echo "  message:<pattern>       - Filtrar por mensaje (regex)"
    echo "  since:<time>            - Filtrar por tiempo (e.g., '5m', '1h', '1d')"
    echo ""
    echo "Opciones:"
    echo "  --last N                - Últimos N líneas"
    echo "  --follow                - Follow logs en tiempo real (tail -f)"
    echo "  --json                  - Output en JSON"
    echo ""
    echo "Ejemplos:"
    echo "  $0 level:error"
    echo "  $0 category:Calendar message:sync"
    echo "  $0 since:5m --last 20"
    echo "  $0 --follow"
    exit 1
fi

QUERY="$1"
shift
OPTIONS=("$@")

# Parsear opciones
LAST_LINES=""
FOLLOW=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --last)
            LAST_LINES="$2"
            shift 2
            ;;
        --follow)
            FOLLOW=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Construir command de log
LOG_CMD="log show --predicate 'subsystem == \"$SUBSYSTEM\"' --info --debug"

# Parsear query
if [[ "$QUERY" == "all" ]]; then
    # Todos los logs
    :
elif [[ "$QUERY" =~ ^level:(debug|info|warning|error|fault)$ ]]; then
    LEVEL="${BASH_REMATCH[1]}"
    LOG_CMD="$LOG_CMD --predicate 'subsystem == \"$SUBSYSTEM\" && eventMessage contains \"$LEVEL\"'"
elif [[ "$QUERY" =~ ^category:([A-Za-z]+)$ ]]; then
    CATEGORY="${BASH_REMATCH[1]}"
    LOG_CMD="$LOG_CMD --predicate 'subsystem == \"$SUBSYSTEM\" && category == \"$CATEGORY\"'"
elif [[ "$QUERY" =~ ^message:(.+)$ ]]; then
    PATTERN="${BASH_REMATCH[1]}"
    LOG_CMD="$LOG_CMD --predicate 'subsystem == \"$SUBSYSTEM\" && eventMessage CONTAINS \"$PATTERN\"'"
elif [[ "$QUERY" =~ ^since:([0-9]+[mhd])$ ]]; then
    TIME="${BASH_REMATCH[1]}"
    LOG_CMD="$LOG_CMD --last \"$TIME\""
else
    echo "Query inválido: $QUERY"
    exit 1
fi

# Aplicar opciones
if [ -n "$LAST_LINES" ]; then
    LOG_CMD="$LOG_CMD --last $LAST_LINES"
fi

if [ "$JSON_OUTPUT" = true ]; then
    LOG_CMD="$LOG_CMD --style json"
else
    LOG_CMD="$LOG_CMD --style syslog"
fi

# Ejecutar
if [ "$FOLLOW" = true ]; then
    # Follow logs en tiempo real
    log stream --predicate "subsystem == \"$SUBSYSTEM\"" --level debug --style syslog
else
    # Show logs históricos
    eval $LOG_CMD
fi