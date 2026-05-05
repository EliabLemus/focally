#!/bin/bash
# Stop manual de Focally menubar app

echo "🛑 Stopping Focally..."

# Preguntar si existe instancia corriendo
if pgrep -x "Focally" > /dev/null; then
  echo "Found running instance, killing..."
  killall Focally 2>/dev/null || true
  sleep 1
fi

# Verificar que se cerró
if pgrep -x "Focally" > /dev/null; then
  echo "⚠️  Force killing Focally..."
  killall -9 Focally
fi

echo "✅ Focally stopped."
