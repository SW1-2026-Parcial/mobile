# Spec: Notificaciones Push Locales con Polling — sp1_mobile

**Fecha:** 2026-04-27
**Plataforma objetivo:** iPhone (iOS) — app en foreground y background
**Alcance:** Feature nueva + corrección de 4 fallas existentes

---

## 1. Contexto

La app actualmente usa Firebase Cloud Messaging (FCM) para push notifications, lo que requiere una cuenta Apple Developer de $99 para funcionar en dispositivos físicos iOS. Se reemplaza ese mecanismo por **notificaciones push locales** (`flutter_local_notifications`) combinadas con un **polling periódico** al backend. No requiere servidor de notificaciones ni cuenta de desarrollador pagada.

El WebSocket STOMP existente sigue funcionando para actualizaciones en tiempo real mientras la app está en foreground. El polling es el mecanismo de fallback/background.

---

## 2. Fallas corregidas en este mismo PR

| ID | Archivo | Descripción | Corrección |
|----|---------|-------------|------------|
| F1 | `lib/core/constants/api_constants.dart:3-4` | `10.0.2.2` es IP del emulador Android, no funciona en iPhone | Cambiar a `localhost` |
| F3 | `lib/domain/service/tramite_services.dart:11` | Retorna `"VERDE"` que no existe en el spec (regla 13 CLAUDE.md solo define rojo/amarillo) | Cambiar a `"COMPLETADO"` |
| F5 | `lib/data/providers/tramite_provider.dart:7` | `http.Client()` creado pero nunca cerrado | Reemplazar por métodos estáticos `http.get()` / `http.post()` |
| F8 | `pubspec.yaml` + `main.dart` + `app.dart` | `firebase_core` y `firebase_messaging` son dead weight para iOS sin $99 | Eliminar dependencias y código Firebase |

Fallas F2 (requestPermission nunca llamado) y F4 (retorno ignorado de registrarDispositivo) se resuelven implícitamente al eliminar FCM y agregar LocalNotificationService.

Fallas F6 (acoplamiento duro) y F7 (sin reconexión WS) quedan fuera de scope — refactors mayores no relacionados con esta feature.

---

## 3. Dependencia nueva

```yaml
# pubspec.yaml — agregar:
flutter_local_notifications: ^18.0.0

# pubspec.yaml — eliminar:
firebase_core: ^4.7.0
firebase_messaging: ^16.0.3
```

No se agrega ningún otro paquete.

---

## 4. Nuevo archivo: `LocalNotificationService`

**Ruta:** `lib/core/services/local_notification_service.dart`

**Responsabilidad única:** inicializar el plugin de notificaciones locales y exponer un método para mostrar notificaciones de actualización de trámite.

### API pública

```dart
class LocalNotificationService {
  Future<void> initialize() async { ... }
  Future<void> showTramiteUpdate({
    required String titulo,
    required String cuerpo,
  }) async { ... }
}
```

### Comportamiento de `initialize()`
- Crea `FlutterLocalNotificationsPlugin`
- Configuración iOS: `DarwinInitializationSettings` con `requestAlertPermission: true`, `requestSoundPermission: true`, `requestBadgePermission: true`
- Llama `initialize()` del plugin con settings iOS
- Llama `resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(...)` para iOS 16+
- Si el usuario deniega permisos, el servicio no lanza excepción — falla silenciosamente con `debugPrint`

### Comportamiento de `showTramiteUpdate()`
- Muestra notificación con ID fijo `42` (sobreescribe la anterior si existe)
- `NotificationDetails` iOS: `DarwinNotificationDetails` con sonido por defecto
- No lanza excepción si el plugin no está inicializado — falla silenciosamente con `debugPrint`

### Mensajes según el tipo de cambio
El llamador (SeguimientoProvider) determina el mensaje; el servicio solo muestra lo que recibe.

---

## 5. Modificaciones a `SeguimientoProvider`

**Ruta:** `lib/presentation/providers/seguimiento_provider.dart`

### Constructor
```dart
// Antes:
SeguimientoProvider(this._fcmService);

// Después:
SeguimientoProvider(this._localNotificationService);
```

### Campos nuevos
```dart
final LocalNotificationService _localNotificationService;
Timer? _pollingTimer;
List<String> _lastNodeIds = [];
TramiteStatus? _lastStatus;
String? _ticketActivo;
static const int _pollingIntervalSec = 30;
```

### Lógica de polling — flujo completo

**`buscarTramite(ticketNumber)`** (modificado):
1. Hace `GET /tramites/ticket/{ticket}` (igual que antes)
2. Guarda `_lastNodeIds = tramite.currentNodeIds` y `_lastStatus = tramite.status` y `_ticketActivo = ticketNumber`
3. Si `status == ACTIVE` → llama `_startPolling()`
4. Si ya `COMPLETED` o `REJECTED` desde el inicio → NO arranca polling
5. Elimina la llamada a `_registrarFcmToken()` (ya no existe FCM)

**`_startPolling()`** (nuevo):
```dart
void _startPolling() {
  _pollingTimer?.cancel();
  _pollingTimer = Timer.periodic(
    const Duration(seconds: _pollingIntervalSec),
    (_) => _pollAndNotify(),
  );
}
```

**`_pollAndNotify()`** (nuevo):
1. Llama `GET /tramites/ticket/{_ticketActivo}`
2. Si falla la llamada HTTP → `debugPrint` y retorna (no cancela el timer)
3. Compara `nuevo.status != _lastStatus` OR `nuevo.currentNodeIds != _lastNodeIds` (comparación de listas por contenido)
4. Si hay cambio:
   - Determina mensaje según tabla de mensajes (ver §5.1)
   - Llama `_localNotificationService.showTramiteUpdate(titulo, cuerpo)`
   - Actualiza `this.tramite = nuevo`, `_lastStatus`, `_lastNodeIds`
   - Llama `notifyListeners()`
5. Si `nuevo.status == COMPLETED || REJECTED` → llama `_stopPolling()`

**`_stopPolling()`** (nuevo):
```dart
void _stopPolling() {
  _pollingTimer?.cancel();
  _pollingTimer = null;
}
```

**`dispose()`** (modificado):
```dart
@override
void dispose() {
  _stopPolling();
  desconectar(); // WebSocket
  super.dispose();
}
```

**`_registrarFcmToken()`** → **eliminado** (ya no existe FCM)

### 5.1 Tabla de mensajes de notificación

| Condición | `titulo` | `cuerpo` |
|-----------|----------|---------|
| `nuevo.status == COMPLETED` | `"Trámite finalizado ✓"` | `"Tu trámite $_ticketActivo ha sido completado"` |
| `nuevo.status == REJECTED` | `"Trámite rechazado"` | `"Tu trámite $_ticketActivo fue rechazado"` |
| `currentNodeIds` cambia (status sigue ACTIVE) | `"Trámite actualizado"` | `"Tu trámite $_ticketActivo avanzó a una nueva etapa"` |

---

## 6. Modificaciones a `app.dart`

- Eliminar `FcmService _fcmService` y `_initFcm()`
- Agregar `LocalNotificationService _localNotificationService`
- En `initState()`: llamar `_localNotificationService.initialize()`
- Pasar `_localNotificationService` al `SeguimientoProvider`
- Pasar `_localNotificationService` a `PoliticasScreen` (para el botón de prueba)

---

## 7. Modificaciones a `main.dart`

- Eliminar `Firebase.initializeApp()`, `fcmBackgroundHandler`, imports de Firebase
- El archivo queda solo con:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BpmClientApp());
}
```

---

## 8. Botón de prueba en `PoliticasScreen` (TEST ONLY)

**Propósito:** verificar manualmente que las notificaciones locales funcionan sin necesitar que el backend cambie el estado de un trámite.

**Implementación:**
- `PoliticasScreen` recibe `LocalNotificationService` por constructor
- Se agrega un `FloatingActionButton` al `Scaffold`
- El bloque completo está delimitado por `// ── TEST ONLY START ──` y `// ── TEST ONLY END ──`
- Al presionar: llama `localNotificationService.showTramiteUpdate(titulo: '🔔 Prueba', cuerpo: 'Notificación local funcionando correctamente')`

**Cómo borrarlo sin errores:**
1. Eliminar el bloque marcado `TEST ONLY` en `politicas_screen.dart` (el FAB)
2. Eliminar el parámetro `localNotificationService` del constructor de `PoliticasScreen`
3. Actualizar `app.dart` para no pasar ese parámetro a `PoliticasScreen`
4. El resto del código no se ve afectado

---

## 9. Modificaciones a `api_constants.dart` (F1)

```dart
// Antes:
static const String baseUrl = "http://10.0.2.2:8080/api";
static const String wsUrl = "ws://10.0.2.2:8080/ws/websocket";

// Después:
static const String baseUrl = "http://localhost:8080/api";
static const String wsUrl = "ws://localhost:8080/ws/websocket";
```

> Nota: en dispositivo físico iPhone conectado por USB con port forwarding activo, `localhost` funciona. Si se prueba en red WiFi local, cambiar a la IP de la máquina (ej. `192.168.x.x`).

---

## 10. Árbol de archivos afectados

```
NUEVO:
  lib/core/services/local_notification_service.dart

MODIFICADOS:
  pubspec.yaml                                        (deps)
  lib/main.dart                                       (eliminar Firebase)
  lib/app.dart                                        (eliminar FCM, agregar LocalNotif)
  lib/core/constants/api_constants.dart               (F1: IP)
  lib/core/services/fcm_service.dart                  (ELIMINAR archivo)
  lib/domain/service/tramite_services.dart            (F3: "VERDE")
  lib/data/providers/tramite_provider.dart            (F5: http.Client)
  lib/data/repositories/tramite_repository.dart       (eliminar registrarDispositivo)
  lib/presentation/providers/seguimiento_provider.dart (polling + local notif)
  lib/presentation/screens/politicas_screen.dart      (botón TEST ONLY)
```

---

## 11. Limitaciones conocidas (aceptadas para esta prueba)

- El timer se suspende ~30 segundos después de que iOS manda la app a background profundo. Mientras la app esté activa o recién minimizada, el polling funciona.
- No hay polling con app killed (requeriría `workmanager` + cuenta $99).
- `localhost` en dispositivo físico requiere que el iPhone esté en la misma red o tenga port forwarding USB activo.
