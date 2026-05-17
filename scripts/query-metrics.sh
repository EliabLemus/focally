#!/bin/bash

# Script para query métricas de Focally estilo PromQL
# Basado en docs/exec-plans/active/PLAN-004_OBSERVABILITY.md

set -e

SUBSYSTEM="app.focally.mac"

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <query> [opciones]"
    echo ""
    echo "Queries soportados:"
    echo "  counters                - Todos los counters"
    echo "  gauges                  - Todos los gauges"
    echo "  histograms              - Todos los histograms"
    echo "  counter:<name>          - Counter específico"
    echo "  gauge:<name>            - Gauge específico"
    echo "  histogram:<name>        - Histogram específico"
    echo ""
    echo "Opciones:"
    echo "  --last N                - Últimos N eventos"
    echo "  --avg                   - Promedio de valores (gauges/histograms)"
    echo "  --sum                   - Suma de valores (counters/histograms)"
    echo "  --p50                   - Percentil 50 (histogram)"
    echo "  --p95                   - Percentil 95 (histogram)"
    echo "  --json                  - Output en JSON"
    echo ""
    echo "Ejemplos:"
    echo "  $0 counters"
    echo "  $0 gauge:current_session_duration"
    echo "  $0 histogram:calendar_sync_duration_ms --p95"
    echo "  $0 counter:sessions_started --sum --last 10"
    exit 1
fi

QUERY="$1"
shift
OPTIONS=("$@")

# Parsear opciones
LAST_EVENTS=""
CALC_AVG=false
CALC_SUM=false
CALC_P50=false
CALC_P95=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --last)
            LAST_EVENTS="$2"
            shift 2
            ;;
        --avg)
            CALC_AVG=true
            shift
            ;;
        --sum)
            CALC_SUM=true
            shift
            ;;
        --p50)
            CALC_P50=true
            shift
            ;;
        --p95)
            CALC_P95=true
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

# Construir command de signpost
SIGNPOST_CMD="log show --predicate 'subsystem == \"$SUBSYSTEM\"' --info --debug"

# Parsear query
if [[ "$QUERY" == "counters" ]]; then
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E '(increment|sessions_|errors)' | grep -v metadata"
elif [[ "$QUERY" == "gauges" ]]; then
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E '(gauge|current_session_duration|calendar_event_count)' | grep -v metadata"
elif [[ "$QUERY" == "histograms" ]]; then
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E '(histogram|calendar_sync_duration)' | grep -v metadata"
elif [[ "$QUERY" =~ ^counter:(.+)$ ]]; then
    COUNTER="${BASH_REMATCH[1]}"
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E \"$COUNTER\" | grep -v metadata"
elif [[ "$QUERY" =~ ^gauge:(.+)$ ]]; then
    GAUGE="${BASH_REMATCH[1]}"
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E \"$GAUGE\" | grep -v metadata"
elif [[ "$QUERY" =~ ^histogram:(.+)$ ]]; then
    HISTOGRAM="${BASH_REMATCH[1]}"
    SIGNPOST_CMD="$SIGNPOST_CMD --predicate 'subsystem == \"$SUBSYSTEM\"' --style compact | grep -E \"$HISTOGRAM\" | grep -v metadata"
else
    echo "Query inválido: $QUERY"
    exit 1
fi

# Aplicar opciones
if [ -n "$LAST_EVENTS" ]; then
    # NOTA: log show no soporta --last para signposts, pero usamos tail como workaround
    SIGNPOST_CMD="$SIGNPOST_CMD | tail -n $LAST_EVENTS"
fi

if [ "$JSON_OUTPUT" = true ]; then
    SIGNPOST_CMD="$SIGNPOST_CMD --style json"
else
    SIGNPOST_CMD="$SIGNPOST_CMD --style compact"
fi

# Ejecutar y parsear
if [ "$CALC_SUM" = true ]; then
    eval $SIGNPOST_CMD | grep -oE '\d+(\.\d+)?' | awk '{sum+=$1} END {print sum}'
elif [ "$CALC_AVG" = true ]; then
    eval $SIGNPOST_CMD | grep -oE '\d+(\.\d+)?' | awk '{sum+=$1; count++} END {print sum/count}'
elif [ "$CALC_P50" = true ]; then
    eval $SIGNPOST_CMD | grep -oE '\d+(\.\d+)?' | sort -n | awk '{a[NR]=$1} END {print a[int(NR/2)]}'
elif [ "$CALC_P95" = true ]; then
    eval $SIGNPOST_CMD | grep -oE '\d+(\.\d+)?' | sort -n | awk '{a[NR]=$1} END {print a[int(NR*0.95)]}'
else
    eval $SIGNPOST_CMD
fi