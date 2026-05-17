#!/bin/bash

# Script para exponer logs/métricas de Focally a DevTools Protocol
# Basado en docs/exec-plans/active/PLAN-004_OBSERVABILITY.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <command> [opciones]"
    echo ""
    echo "Comandos:"
    echo "  start                   - Iniciar servidor DevTools"
    echo "  stop                    - Detener servidor DevTools"
    echo "  logs                    - Exponer logs vía DevTools"
    echo "  metrics                 - Exponer métricas vía DevTools"
    echo ""
    echo "Opciones:"
    echo "  --port PORT             - Puerto del servidor (default: 9222)"
    echo "  --follow                - Follow logs en tiempo real"
    echo ""
    echo "Ejemplos:"
    echo "  $0 start"
    echo "  $0 logs --follow"
    echo "  $0 metrics --port 9223"
    exit 1
fi

COMMAND="$1"
shift

PORT=9222
FOLLOW=false

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --follow)
            FOLLOW=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Iniciar servidor DevTools (simulado)
# NOTA: DevTools Protocol real requiere implementación en Swift
# Este es un placeholder para demostrar el concepto

case "$COMMAND" in
    start)
        echo "Iniciando servidor DevTools en puerto $PORT..."
        # En una implementación real, esto iniciaría un servidor WebSocket
        # que exponga logs/métricas vía Chrome DevTools Protocol
        echo "DevTools server iniciado (placeholder)"
        echo "NOTA: Implementación real requiere servidor WebSocket en Swift"
        ;;
    stop)
        echo "Deteniendo servidor DevTools..."
        echo "DevTools server detenido (placeholder)"
        ;;
    logs)
        echo "Exponiendo logs vía DevTools en puerto $PORT..."
        if [ "$FOLLOW" = true ]; then
            log stream --predicate 'subsystem == "app.focally.mac"' --level debug --style compact
        else
            log show --predicate 'subsystem == "app.focally.mac"' --info --debug --style compact | tail -50
        fi
        ;;
    metrics)
        echo "Exponiendo métricas vía DevTools en puerto $PORT..."
        ./scripts/query-metrics.sh counters
        ./scripts/query-metrics.sh gauges
        ./scripts/query-metrics.sh histograms
        ;;
    *)
        echo "Comando inválido: $COMMAND"
        exit 1
        ;;
esac