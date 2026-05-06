# Focally v0.7.1 - Focus Integration Guide

## Cómo Funciona la Integración de Focus

Hay **dos métodos** para usar la integración con macOS Focus:

### Método 1: Drag & Drop de Shortcuts (RECOMENDADO)
Este es el método "zero setup" que implementa v0.7.1.

### Método 2: Configuración Manual (Opción Legacy)
Puedes crear tus propios shortcuts manualmente en la app de Shortcuts de Apple.

---

## Método 1: Drag & Drop (Recomendado)

### Paso 1: Encontrar los archivos de shortcuts

Focally **genera automáticamente** los shortcuts de prueba al primer lanzamiento:

```bash
# Los shortcuts están aquí:
~/Library/Application Support/Focally/Shortcuts/
```

Archivos generados:
- `Focally Focus On.shortcut`
- `Focally Focus Off.shortcut`

### Paso 2: Abrir Focally

```bash
open -a Focally
```

### Paso 3: Ir a Settings → Integrations

En la app de Focally:
1. Click en el ícono de menú bar (⏳)
2. Click en "Settings"
3. Click en "Integrations" (icono de puzzle 🧩)

### Paso 4: Ver la zona de Drop

En "Integrations", verás una **"Focus Integration"** card.

Debajo de la toggle de "Focus Integration", verás:

**Si NO has arrastrado shortcuts:**
```
┌────────────────────────────────────────────┐
│                                            │
│        ↓  Drag & Drop .shortcut file       │
│                                            │
│  Drop shortcuts here to install them...      │
│                                            │
└────────────────────────────────────────────┘
```

### Paso 5: Arrastrar los shortcuts

1. Abre **Finder**
2. Ve a: `~/Library/Application Support/Focally/Shortcuts/`
3. Arrastra **BOTH** archivos a la zona de drop:
   - `Focally Focus On.shortcut`
   - `Focally Focus Off.shortcut`

**Cuando arrastras:**
- El ícono cambia a color púrpura
- Aparece el mensaje: "Drop shortcut here"
- Suelta los archivos

### Paso 6: Verificar instalación

Después de soltar:
- Aparece un icono de checkmark ✅
- Aparece el mensaje: "✅ Shortcut installed"
- Focally copia los archivos a: `~/Library/Shortcuts/`
- Focally abre automáticamente la app de Apple Shortcuts para importar

### Paso 7: Activar la integración

En la misma "Focus Integration" card:
1. Click en el toggle para activar "Focus Integration"
2. Ahora Focally usará los shortcuts cuando inicies/finalizes sesiones

### Paso 8: ¡Listo!

Ahora cuando inicies una sesión de foco:
- Focally corre el shortcut "Focally Focus On"
- El shortcut activa DND + modo Focus de trabajo
- Cuando finalizas, Focally corre "Focally Focus Off"
- El shortcut desactiva DND

---

## Método 2: Crear Shortcuts Manualmente (Opción B)

Si prefieres crear tus propios shortcuts:

### Paso 1: Abrir la app de Shortcuts

```bash
open -a Shortcuts
```

### Paso 2: Crear "Focally Focus On"

1. Click en **+** (New Shortcut)
2. Nombra el shortcut: **"Focally Focus On"**
3. Agrega acciones:
   - Acción 1: **"Set Focus Mode"**
     - Toggle Do Not Disturb: **ON**
   - Acción 2: **"Set Focus"**
     - Focus Mode: **Work**
4. Click en **Done**

### Paso 3: Crear "Focally Focus Off"

1. Click en **+** (New Shortcut)
2. Nombra el shortcut: **"Focally Focus Off"**
3. Agrega acciones:
   - Acción 1: **"Set Focus Mode"**
     - Toggle Do Not Disturb: **OFF**
   - Acción 2: **"Turn Off Focus"** (opcional)
4. Click en **Done**

### Paso 4: Ir a Settings → Integrations en Focally

En Focally:
1. Click en el menú bar (⏳)
2. Click en "Settings"
3. Click en "Integrations"

### Paso 5: Configurar los shortcuts

En "Integrations", verás:

**Si "Focus Integration" está desactivado:**
- Activa el toggle de "Focus Integration"
- Verás las opciones de configuración

**Configura:**
- "Mode": Selecciona **"Shortcuts"** (o "Recommended")
- "Start Shortcut": Escribe: **Focally Focus On**
- "End Shortcut": Escribe: **Focally Focus Off**

### Paso 6: ¡Listo!

Focally usará tus shortcuts manualmente creados.

---

## Troubleshooting

### Problema: No veo los archivos de shortcuts

**Solución:**
1. Reabre Focally (se generan al primer lanzamiento)
2. Si no aparecen, verifica la ruta:
   ```bash
   ls ~/Library/Application\ Support/Focally/Shortcuts/
   ```
3. Si no existe el directorio:
   ```bash
   mkdir -p ~/Library/Application\ Support/Focally/Shortcuts/
   ```

### Problema: La zona de drop no aparece

**Solución:**
1. Ve a Settings → Integrations
2. Asegúrate de que "Focus Integration" esté visible
3. Si no está, reinstala Focally:
   ```bash
   brew reinstall --cask focally
   ```

### Problema: El shortcut no funciona

**Solución:**
1. Abre la app de Apple Shortcuts
2. Busca el shortcut por nombre
3. Click en el botón de Play ▶️
4. Verifica que activa/desactiva DND
5. Si no funciona, recrea el shortcut manualmente

### Problema: DND no se activa

**Solución:**
1. Ve a System Settings → Notifications
2. Verifica que Focally tenga permisos de Accessibility
3. Si no, añade Focally:
   - Privacy & Security → Accessibility → Add Focally

---

## Verificación

### Para verificar que funciona:

1. **Activa la integración:**
   - Settings → Integrations → Focus Integration: ON

2. **Inicia una sesión:**
   - Click en "Start Focus" (25 min por ejemplo)
   - Verifica que DND se activa (menú bar > Focus icon)

3. **Finaliza la sesión:**
   - Click en "Stop" o espera a que termine
   - Verifica que DND se desactiva

4. **Verifica el badge:**
   - Click en el menú bar (⏳)
   - Abre el dropdown
   - Deberías ver "DND Active" en púrpura bajo "Deep Focus Mode"

---

## Resumen Rápido

### Para usar Drag & Drop (Recomendado):

1. Focally genera shortcuts en: `~/Library/Application Support/Focally/Shortcuts/`
2. Abre Focally → Settings → Integrations
3. Arrastra `Focally Focus On.shortcut` y `Focally Focus Off.shortcut` a la zona de drop
4. Activa "Focus Integration"
5. ¡Listo!

### Para usar Shortcuts Manualmente:

1. Abre la app de Shortcuts
2. Crea shortcuts con acciones de DND/Focus
3. En Focally → Settings → Integrations:
   - Activa "Focus Integration"
   - Nombra los shortcuts en "Start Shortcut" y "End Shortcut"
4. ¡Listo!

---

## Preguntas Frecuentes

**Q: ¿Cuál método es mejor?**
A: Drag & Drop es mejor porque es "zero setup" - Focally hace todo automáticamente.

**Q: ¿Puedo usar ambos métodos?**
A: No, usa uno u otro. Drag & Drop es el recomendado.

**Q: ¿Qué hace exactamente el shortcut?**
A:
- "Focally Focus On" → Activa DND + modo Focus de trabajo
- "Focally Focus Off" → Desactiva DND (y Focus si aplica)

**Q: ¿Puedo crear shortcuts personalizados?**
A: Sí, usa Método 2. Pero los shortcuts de prueba de Focally ya deberían funcionar.

**Q: ¿El shortcut funciona sin Focally abierto?**
A: Sí, son shortcuts de Apple que funcionan independientemente de Focally. Focally solo los corre automáticamente.

---

## Necesitas Ayuda?

Si algo no funciona:
1. Reinstala Focally: `brew reinstall --cask focally`
2. Verifica los archivos: `ls ~/Library/Application\ Support/Focally/Shortcuts/`
3. Contacta a Eliab: @eliab en Telegram

---

**Versión**: v0.7.1
**Fecha**: 2026-05-06
