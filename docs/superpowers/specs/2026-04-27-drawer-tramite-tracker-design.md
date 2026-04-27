# Spec: Drawer de Navegación + TramiteTrackerProvider — sp1_mobile

**Fecha:** 2026-04-27
**Alcance:** Navegación con Drawer + tracking en memoria de hasta 3 trámites con polling simultáneo

---

## 1. Contexto

La app actualmente no tiene forma de navegar a `SeguimientoScreen` desde la pantalla principal, ni de mantener una lista de trámites seguidos. Se agrega un Navigation Drawer accesible desde cualquier pantalla, un provider centralizado que gestiona hasta 3 trámites simultáneos con un único timer de polling, y la integración con `LocalNotificationService` ya existente.

---

## 2. Archivos afectados

```
NUEVOS:
  lib/presentation/providers/tramite_tracker_provider.dart
  lib/presentation/widgets/app_shell.dart

MODIFICADOS:
  lib/app.dart
  lib/presentation/screens/seguimiento_screen.dart
  lib/presentation/providers/seguimiento_provider.dart   (eliminar polling propio)
```

---

## 3. `TramiteTrackerProvider`

**Ruta:** `lib/presentation/providers/tramite_tracker_provider.dart`

### Responsabilidad
Mantiene en memoria la lista de trámites seguidos (máx 3), corre un único `Timer.periodic` de 10 s que consulta todos los trámites activos y dispara notificaciones locales si hay cambios.

### Estado interno
```dart
static const int maxTramites = 3;
final Map<String, TramiteModel> _tracked = {};  // ticketNumber → modelo
final Map<String, List<String>> _lastNodeIds = {};  // ticketNumber → últimos nodeIds
final Map<String, TramiteStatus> _lastStatus = {};  // ticketNumber → último status
Timer? _timer;
```

### API pública
```dart
List<TramiteModel> get tramites          // lista actual
bool get estaLleno                        // true si ya hay 3
void agregar(TramiteModel tramite)        // no-op si ya existe o lleno
void remover(String ticketNumber)         // quita de lista; cancela timer si queda vacío
```

### Lógica del timer

**`agregar()`:**
- Si `_tracked.containsKey(tramite.ticketNumber)` → no-op
- Si `estaLleno` → no-op (el caller muestra el SnackBar)
- Agrega a `_tracked`, `_lastNodeIds`, `_lastStatus`
- Si era el primero → arranca timer
- `notifyListeners()`

**`remover()`:**
- Elimina de los tres mapas
- Si `_tracked` queda vacío → cancela timer
- `notifyListeners()`

**`_pollAll()` (tick del timer):**
Para cada `ticketNumber` en `_tracked` donde `status == ACTIVE`:
1. `GET /tramites/ticket/{ticketNumber}` — si falla, continúa con el siguiente
2. Compara `nuevo.status != _lastStatus[ticket]` OR `nuevo.currentNodeIds != _lastNodeIds[ticket]`
3. Si hay cambio → `localNotif.showTramiteUpdate(titulo, cuerpo)` + actualiza `_tracked`, `_lastStatus`, `_lastNodeIds`
4. Si `nuevo.status == COMPLETED || REJECTED` → actualiza modelo pero deja en lista (usuario lo ve); deja de pollear en ticks futuros (el filtro `status == ACTIVE` lo excluye automáticamente)
5. `notifyListeners()` si hubo algún cambio

**Mensajes de notificación** — misma tabla que el spec anterior:
| Condición | Título | Cuerpo |
|-----------|--------|--------|
| status → COMPLETED | "Trámite finalizado ✓" | "Tu trámite {ticket} ha sido completado" |
| status → REJECTED | "Trámite rechazado" | "Tu trámite {ticket} fue rechazado" |
| currentNodeIds cambia | "Trámite actualizado" | "Tu trámite {ticket} avanzó a una nueva etapa" |

### Comparación de listas
Usar comparación por contenido ordenado (misma lógica que `_listasIguales` en `SeguimientoProvider`).

---

## 4. `AppShell`

**Ruta:** `lib/presentation/widgets/app_shell.dart`

Widget que envuelve todas las pantallas. Provee `Scaffold` con `AppBar` y `Drawer`.

### Props
```dart
class AppShell extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;  // acciones opcionales del AppBar
}
```

### Estructura del Drawer
```
DrawerHeader
  → texto: "BPM — Mis Trámites"
  → fondo color primario (0xFF3F51B5)

ListTile
  → leading: Icon(Icons.list_alt)
  → title: "Catálogo de Políticas"
  → onTap: Navigator.pushReplacementNamed(context, '/')

Divider

Padding → "Trámites seguidos (N/3)"  ← Consumer<TramiteTrackerProvider>

Para cada tramite en trackerProvider.tramites:
  ListTile
    → leading: Icon con color según status
        ACTIVE    → Icons.hourglass_top, color amarillo (Colors.orange)
        COMPLETED → Icons.check_circle, color verde (Colors.green)
        REJECTED  → Icons.cancel, color rojo (Colors.red)
        PAUSED    → Icons.pause_circle, color gris
    → title: Text(tramite.ticketNumber)
    → trailing: IconButton(Icons.delete_outline, color rojo)
        onPressed: trackerProvider.remover(tramite.ticketNumber)
    → onTap: Navigator.pop(context) + pushNamed('/seguimiento', arguments: tramite.ticketNumber)

Si trackerProvider.tramites.isEmpty:
  Padding → Text("Sin trámites seguidos", color gris)
```

---

## 5. Cambios a `SeguimientoScreen`

### Auto-agregar al tracker
En `buscarTramite()` del provider, cuando se encuentra el trámite exitosamente:
- El **screen** (no el provider) lee `TramiteTrackerProvider` y llama `agregar()`
- Si `trackerProvider.estaLleno` antes de agregar → muestra `SnackBar`: *"Límite de 3 trámites alcanzado. Deja de seguir uno para agregar este."*
- Si ya está en la lista → no muestra nada (silencioso)

La lógica de "agregar" va en `didChangeDependencies` del screen después de que `SeguimientoProvider` termina de buscar, usando un `addPostFrameCallback`.

### Botón "Dejar de seguir"
- Aparece como `IconButton` en el `AppBar` de `AppShell` (se pasa como `actions`)
- Solo visible si `trackerProvider.tramites.any((t) => t.ticketNumber == ticketActual)`
- `onPressed`: `trackerProvider.remover(ticketNumber)` + `SnackBar`: *"Dejaste de seguir este trámite"*

### Scaffold
`SeguimientoScreen` deja de tener su propio `Scaffold` + `AppBar`. Los provee `AppShell`.

---

## 6. Cambios a `SeguimientoProvider`

Eliminar:
- `_pollingTimer`, `_lastNodeIds`, `_lastStatus`, `_ticketActivo`, `_pollingIntervalSec`
- `_startPolling()`, `_stopPolling()`, `_pollAndNotify()`, `_listasIguales()`, `_tituloNotif()`, `_cuerpoNotif()`
- Campo `_localNotificationService` y parámetro del constructor

El polling lo maneja exclusivamente `TramiteTrackerProvider`. `SeguimientoProvider` queda con solo: `buscarTramite()`, `_conectarWebSocket()`, `desconectar()`, `dispose()`.

Constructor simplificado:
```dart
SeguimientoProvider();  // sin parámetros
```

---

## 7. Cambios a `app.dart`

- Agregar `TramiteTrackerProvider` al `MultiProvider`
  - Requiere `LocalNotificationService` y `TramiteRepository` — se crean en `_BpmClientAppState`
- `SeguimientoProvider` ya no recibe `_localNotifService`
- Rutas usan `AppShell` implícitamente (cada screen lo usa internamente)

---

## 8. `PoliticasScreen`

- Se elimina el parámetro `localNotifService` del constructor (ya no lo necesita la pantalla — el tracker lo gestiona)
- El botón TEST ONLY permanece pero llama directamente a través del `TramiteTrackerProvider`... No — para no complicar, el botón TEST ONLY se mueve a `AppShell` o se elimina. **Decisión: eliminarlo** — ya fue probado y cumplió su propósito.

---

## 9. Limitaciones aceptadas

- La lista se pierde al cerrar la app (in-memory only, por decisión del usuario)
- Máximo 3 trámites simultáneos
- Si todos los trámites rastreados están COMPLETED/REJECTED, el timer se cancela automáticamente al final de `_pollAll()` (verificar si quedan activos tras el ciclo; si no → `_timer?.cancel()`). Se reactiva si se agrega un nuevo trámite ACTIVE.
