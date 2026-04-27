# Pantallas: Catálogo de Políticas y Seguimiento de Trámite — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir dos pantallas Flutter (catálogo de políticas y seguimiento de trámite con timeline + push notifications) integrando la infraestructura de red, WebSocket y FCM ya existente en `/lib`.

**Architecture:** `Provider` (ChangeNotifier) como capa de estado. Cada pantalla tiene su propio provider. La infraestructura de red (`TramiteProvider`, `StompClientConfig`) ya existe y se reutiliza sin modificar. Un servicio FCM centralizado (`FcmService`) gestiona permisos, token y navegación desde background.

**Tech Stack:** Flutter 3.x · `provider ^6.1.5` · `firebase_messaging ^16.0.3` · `stomp_dart_client ^3.0.1` · `http ^1.6.0`

---

## Estado del código existente

```
lib/
├── core/
│   ├── constants/api_constants.dart       ✅ BASE_URL, WS_URL, endpoints
│   └── network/stomp_client_config.dart   ✅ STOMP connect/disconnect
├── data/
│   ├── providers/tramite_provider.dart    ✅ HTTP: GET tramite, POST fcm-token, GET policies
│   └── repositories/
│       ├── tramite_repository.dart        ✅ registrarDispositivo, obtenerEstadoActual
│       └── politica_repository.dart       ✅ obtenerCatalogoPublico
├── domain/
│   ├── models/
│   │   ├── tramite_model.dart             ✅ TramiteModel + TramiteStatus enum
│   │   ├── politica_model.dart            ✅ PoliticaModel
│   │   └── tramite_event.dart             ✅ TramiteEvent
│   └── service/tramite_services.dart      ✅ obtenerColorNodo, ordenarEventosPorFecha
└── main.dart                              ⚠️ esqueleto básico — requiere refactor
```

## Mapa de archivos a crear / modificar

| Archivo | Acción | Responsabilidad |
|---------|--------|-----------------|
| `lib/core/services/fcm_service.dart` | CREAR | Permisos FCM, obtener token, background handler, tap handler |
| `lib/presentation/providers/politica_catalog_provider.dart` | CREAR | Estado de carga de políticas |
| `lib/presentation/providers/seguimiento_provider.dart` | CREAR | Estado de seguimiento: ticket lookup, FCM register, WS, eventos |
| `lib/presentation/widgets/politica_card.dart` | CREAR | Tarjeta visual de una política |
| `lib/presentation/widgets/tramite_status_badge.dart` | CREAR | Badge de estado (ACTIVE/COMPLETED/REJECTED/PAUSED) |
| `lib/presentation/widgets/tramite_timeline.dart` | CREAR | Timeline visual de eventos del trámite |
| `lib/presentation/screens/politicas_screen.dart` | CREAR | Pantalla catálogo de políticas |
| `lib/presentation/screens/seguimiento_screen.dart` | CREAR | Pantalla seguimiento con ticket input + timeline |
| `lib/app.dart` | CREAR | MaterialApp + MultiProvider + rutas nombradas |
| `lib/main.dart` | MODIFICAR | Registrar FCM background handler (top-level), llamar app.dart |

---

## ⏱ Timeline de Push Notifications — Dónde toca cada archivo

```
PUSH NOTIFICATION FLOW
──────────────────────
[1] main.dart
    └── FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler)
        ← DEBE ser función top-level (fuera de cualquier clase)
        ← PRIMER punto de entrada cuando la app está cerrada/background

[2] lib/core/services/fcm_service.dart
    ├── requestPermission()         ← solicitar permisos al usuario
    ├── getToken()                  ← obtener FCM token para registrar en backend
    ├── setupForegroundHandler()    ← mostrar notificación mientras app está abierta
    └── setupTapHandler()           ← manejar tap en notificación → navegar a pantalla

[3] lib/presentation/providers/seguimiento_provider.dart
    └── registrarDispositivoConFcm(ticket)
        ├── llama FcmService.getToken()
        └── llama TramiteRepository.registrarDispositivo(ticket, token)
            ← REGISTRO del token en backend → activa las push del trámite

[4] Backend (Spring Boot)
    └── envía push FCM con payload:
        { tramiteId, ticketNumber, eventType, status }
        ← al ocurrir NODE_ENTERED / COMPLETED / CANCELLED

[5] lib/core/services/fcm_service.dart → setupTapHandler()
    └── al tocar la notificación → navegar a SeguimientoScreen con ticketNumber
        ← NAVEGACIÓN desde notificación background/terminated
```

---

## Task 1: FcmService — Servicio centralizado de Push Notifications

**⚠️ PUSH NOTIFICATION — Punto central de configuración FCM**

**Files:**
- Create: `lib/core/services/fcm_service.dart`

- [ ] **Step 1: Crear el archivo FcmService**

```dart
// lib/core/services/fcm_service.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATIONS — FcmService
// ══════════════════════════════════════════════════════════════════
// Responsabilidad: centralizar toda la lógica de Firebase Cloud Messaging.
//
// TIMELINE PUSH:
//   1. requestPermission()       → solicitar permisos iOS/Android
//   2. getToken()                → obtener token para registrar en backend
//   3. setupForegroundHandler()  → mostrar notif mientras app está en foreground
//   4. setupTapHandler()         → navegar al abrir notif desde background/terminated
// ══════════════════════════════════════════════════════════════════

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Servicio que encapsula toda la interacción con Firebase Cloud Messaging.
///
/// Uso típico en [app.dart]:
/// ```dart
/// final fcmService = FcmService();
/// await fcmService.requestPermission();
/// await fcmService.setupForegroundHandler();
/// fcmService.setupTapHandler(navigatorKey);
/// ```
class FcmService {
  // ── PUSH NOTIFICATION ── instancia singleton de FCM
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Paso 1: Solicitar permisos
  // ─────────────────────────────────────────────────────────────────

  /// Solicita permisos de notificación al usuario (requerido en iOS, recomendado en Android 13+).
  ///
  /// Devuelve [true] si el usuario otorgó permisos (authorized o provisional).
  Future<bool> requestPermission() async {
    // ── PUSH NOTIFICATION ── solicitar alert, badge y sound
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Paso 2: Obtener token FCM del dispositivo
  // ─────────────────────────────────────────────────────────────────

  /// Obtiene el token FCM del dispositivo actual.
  ///
  /// Este token se registra en el backend vía
  /// `POST /api/tramites/ticket/{ticketNumber}/fcm-token`
  /// para que el backend pueda enviar pushes a este dispositivo específico.
  ///
  /// Puede devolver [null] si APNS no está listo (solo en iOS simulador).
  Future<String?> getToken() async {
    try {
      // ── PUSH NOTIFICATION ── obtener token del dispositivo
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Error al obtener token: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Paso 3: Manejar notificaciones en foreground
  // ─────────────────────────────────────────────────────────────────

  /// Configura el handler para cuando llega una notificación y la app está abierta.
  ///
  /// [onMessage]: callback que recibe el [RemoteMessage] con el payload FCM.
  /// El payload `data` contiene: tramiteId, ticketNumber, eventType, status.
  void setupForegroundHandler({required void Function(RemoteMessage) onMessage}) {
    // ── PUSH NOTIFICATION ── listener de mensajes en foreground
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Paso 4: Navegar al tocar notificación
  // ─────────────────────────────────────────────────────────────────

  /// Configura navegación cuando el usuario toca una notificación
  /// (app en background o terminada).
  ///
  /// [navigatorKey]: key del Navigator global para poder navegar sin contexto.
  /// Navega a `/seguimiento` pasando el `ticketNumber` del payload FCM.
  void setupTapHandler(GlobalKey<NavigatorState> navigatorKey) {
    // ── PUSH NOTIFICATION ── app abierta desde background al tocar notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navegarASeguimiento(navigatorKey, message);
    });

    // ── PUSH NOTIFICATION ── app abierta desde estado terminado (killed) al tocar notif
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _navegarASeguimiento(navigatorKey, message);
      }
    });
  }

  /// Extrae [ticketNumber] del payload FCM y navega a la pantalla de seguimiento.
  ///
  /// El backend siempre envía `ticketNumber` en `message.data` según CONTEXTO_MOVIL.md §7.
  void _navegarASeguimiento(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    // ── PUSH NOTIFICATION ── extraer ticketNumber del payload data del backend
    final ticketNumber = message.data['ticketNumber'] as String?;
    if (ticketNumber != null && ticketNumber.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(
        '/seguimiento',
        arguments: ticketNumber,
      );
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/services/fcm_service.dart
git commit -m "feat(fcm): add FcmService — permission, token, foreground/tap handlers"
```

---

## Task 2: PoliticaCatalogProvider — Estado del catálogo de políticas

**Files:**
- Create: `lib/presentation/providers/politica_catalog_provider.dart`

- [ ] **Step 1: Crear el provider**

```dart
// lib/presentation/providers/politica_catalog_provider.dart
//
// Responsabilidad: gestionar el estado de carga del catálogo de políticas.
// Conecta PoliticaRepository con la UI mediante ChangeNotifier.

import 'package:flutter/material.dart';
import '../../data/repositories/politica_repository.dart';
import '../../domain/models/politica_model.dart';

/// Provider de estado para la pantalla de catálogo de políticas.
///
/// Escucha cambios con [ChangeNotifier] y expone:
/// - [politicas]: lista de políticas publicadas.
/// - [isLoading]: indica si hay una carga en curso.
/// - [errorMessage]: mensaje de error si la carga falló.
///
/// Uso en widget:
/// ```dart
/// context.read<PoliticaCatalogProvider>().cargarPoliticas();
/// ```
class PoliticaCatalogProvider extends ChangeNotifier {
  final PoliticaRepository _repository = PoliticaRepository();

  /// Lista de políticas públicas obtenidas del backend.
  List<PoliticaModel> politicas = [];

  /// Indica si la carga HTTP está en progreso.
  bool isLoading = false;

  /// Mensaje de error si la última carga falló. Null si no hay error.
  String? errorMessage;

  // ───────────────────────────────────────────────────────────────

  /// Carga el catálogo de políticas publicadas desde el backend.
  ///
  /// Llama a `GET /api/policies/public` vía [PoliticaRepository].
  /// Actualiza [isLoading], [politicas] y [errorMessage].
  Future<void> cargarPoliticas() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      politicas = await _repository.obtenerCatalogoPublico();
    } catch (e) {
      errorMessage = 'No se pudo cargar el catálogo de políticas. Intenta de nuevo.';
      debugPrint('[PoliticaCatalogProvider] Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/providers/politica_catalog_provider.dart
git commit -m "feat(provider): add PoliticaCatalogProvider"
```

---

## Task 3: SeguimientoProvider — Estado de seguimiento de trámite

**⚠️ PUSH NOTIFICATION — Aquí se registra el token FCM en el backend**

**Files:**
- Create: `lib/presentation/providers/seguimiento_provider.dart`

- [ ] **Step 1: Crear el provider**

```dart
// lib/presentation/providers/seguimiento_provider.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATION — SeguimientoProvider
// ══════════════════════════════════════════════════════════════════
// Responsabilidad: orquestar el flujo completo de seguimiento:
//   1. buscarTramite(ticket)          → GET estado inicial
//   2. registrarDispositivoConFcm()   → POST fcm-token al backend ← ACTIVA PUSH
//   3. conectarWebSocket()            → WS /topic/tramites/{tramiteId}
//   4. desconectar()                  → liberar WS al salir
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/network/stomp_client_config.dart';
import '../../core/services/fcm_service.dart';
import '../../data/repositories/tramite_repository.dart';
import '../../domain/models/tramite_event.dart';
import '../../domain/models/tramite_model.dart';
import '../../domain/service/tramite_services.dart';

/// Estados posibles del proceso de búsqueda de un trámite.
enum SeguimientoEstado { inicial, cargando, activo, completado, error }

/// Provider de estado para la pantalla de seguimiento de trámite.
///
/// Gestiona el ciclo de vida completo:
/// búsqueda HTTP → registro FCM → suscripción WebSocket → recepción de eventos.
///
/// Escucha con [ChangeNotifier]. Limpiar con [desconectar] en [dispose].
class SeguimientoProvider extends ChangeNotifier {
  final TramiteRepository _repository = TramiteRepository();
  final StompClientConfig _stompConfig = StompClientConfig();
  final TramiteService _tramiteService = TramiteService();

  // ── PUSH NOTIFICATION ── servicio FCM inyectado para obtener token
  final FcmService _fcmService;

  SeguimientoProvider(this._fcmService);

  /// Modelo del trámite activo. Null si aún no se ha buscado.
  TramiteModel? tramite;

  /// Lista de eventos WebSocket recibidos en tiempo real.
  /// Representa la línea de tiempo del trámite.
  List<TramiteEvent> eventos = [];

  /// Estado actual del proceso de seguimiento.
  SeguimientoEstado estado = SeguimientoEstado.inicial;

  /// Mensaje de error. Null si no hay error.
  String? errorMessage;

  // ─────────────────────────────────────────────────────────────────
  // Paso 1: Buscar trámite por ticketNumber
  // ─────────────────────────────────────────────────────────────────

  /// Busca el trámite por [ticketNumber] y luego registra el FCM y conecta el WS.
  ///
  /// Secuencia completa:
  /// 1. GET /api/tramites/ticket/{ticketNumber} → estado inicial
  /// 2. POST /api/tramites/ticket/{ticketNumber}/fcm-token → activa push  ← PUSH
  /// 3. WS /topic/tramites/{tramiteId} → recepción en tiempo real
  Future<void> buscarTramite(String ticketNumber) async {
    estado = SeguimientoEstado.cargando;
    errorMessage = null;
    eventos = [];
    notifyListeners();

    try {
      // 1. Obtener estado inicial del trámite
      tramite = await _repository.obtenerEstadoActual(ticketNumber);

      // 2. Registrar token FCM en backend → activa notificaciones push para este trámite
      await _registrarFcmToken(ticketNumber);

      // 3. Conectar WebSocket para actualizaciones en tiempo real
      _conectarWebSocket(tramite!.id);

      estado = tramite!.status == TramiteStatus.COMPLETED ||
              tramite!.status == TramiteStatus.REJECTED
          ? SeguimientoEstado.completado
          : SeguimientoEstado.activo;
    } catch (e) {
      errorMessage = 'No se encontró el trámite. Verifica el número de ticket.';
      estado = SeguimientoEstado.error;
      debugPrint('[SeguimientoProvider] Error en buscarTramite: $e');
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Paso 2: Registrar token FCM en backend
  // ─────────────────────────────────────────────────────────────────

  /// Obtiene el token FCM del dispositivo y lo registra en el backend.
  ///
  /// El backend usa este token para enviar push notifications cuando
  /// el trámite avanza (NODE_ENTERED), se completa (COMPLETED) o es cancelado.
  ///
  /// Si falla (ej. iOS simulador sin APNS), el seguimiento continúa
  /// sin push pero con WebSocket funcional.
  Future<void> _registrarFcmToken(String ticketNumber) async {
    try {
      // ── PUSH NOTIFICATION ── obtener token del dispositivo
      final fcmToken = await _fcmService.getToken();
      if (fcmToken != null) {
        // ── PUSH NOTIFICATION ── POST al backend: activa envío de push para este trámite
        await _repository.registrarDispositivo(ticketNumber, fcmToken);
        debugPrint('[SeguimientoProvider] FCM token registrado para $ticketNumber');
      }
    } catch (e) {
      // No bloquear el seguimiento si el registro FCM falla
      debugPrint('[SeguimientoProvider] Advertencia: no se pudo registrar FCM token: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Paso 3: Conectar WebSocket STOMP
  // ─────────────────────────────────────────────────────────────────

  /// Conecta al WebSocket STOMP y se suscribe al topic del trámite.
  ///
  /// Cada mensaje recibido se convierte en un [TramiteEvent] y se agrega
  /// a [eventos], actualizando el estado del trámite en tiempo real.
  void _conectarWebSocket(String tramiteId) {
    _stompConfig.connect(tramiteId, (data) {
      final evento = TramiteEvent.fromJson(data);
      eventos.add(evento);
      _tramiteService.ordenarEventosPorFecha(eventos);

      // Actualizar estado del trámite si el evento indica finalización
      if (evento.eventType == 'COMPLETED' || evento.eventType == 'CANCELLED') {
        estado = SeguimientoEstado.completado;
      }

      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // Ciclo de vida
  // ─────────────────────────────────────────────────────────────────

  /// Desconecta el WebSocket STOMP. Llamar en el [dispose] del widget.
  void desconectar() {
    try {
      _stompConfig.disconnect();
    } catch (_) {}
  }

  @override
  void dispose() {
    desconectar();
    super.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/providers/seguimiento_provider.dart
git commit -m "feat(provider): add SeguimientoProvider — FCM register + WS subscribe"
```

---

## Task 4: TramiteStatusBadge — Widget de estado del trámite

**Files:**
- Create: `lib/presentation/widgets/tramite_status_badge.dart`

- [ ] **Step 1: Crear el widget**

```dart
// lib/presentation/widgets/tramite_status_badge.dart
//
// Responsabilidad: badge visual de color para el estado del trámite.
// Colores según regla de negocio: rojo=pendiente, amarillo=activo.

import 'package:flutter/material.dart';
import '../../domain/models/tramite_model.dart';

/// Badge que muestra el estado del trámite con color y texto.
///
/// Colores del sistema BPM:
/// - ACTIVE    → amarillo (en proceso)
/// - COMPLETED → verde    (finalizado con éxito)
/// - REJECTED  → rojo     (rechazado)
/// - PAUSED    → gris     (pausado)
class TramiteStatusBadge extends StatelessWidget {
  /// Estado del trámite a mostrar.
  final TramiteStatus status;

  const TramiteStatusBadge({super.key, required this.status});

  /// Devuelve el color del badge según el estado.
  Color _color() {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return const Color(0xFFFFC107); // amarillo — en proceso
      case TramiteStatus.COMPLETED:
        return const Color(0xFF4CAF50); // verde — completado
      case TramiteStatus.REJECTED:
        return const Color(0xFFF44336); // rojo — rechazado
      case TramiteStatus.PAUSED:
        return const Color(0xFF9E9E9E); // gris — pausado
    }
  }

  /// Devuelve el texto del badge según el estado.
  String _label() {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return 'En proceso';
      case TramiteStatus.COMPLETED:
        return 'Completado';
      case TramiteStatus.REJECTED:
        return 'Rechazado';
      case TramiteStatus.PAUSED:
        return 'Pausado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color(), width: 1.2),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/tramite_status_badge.dart
git commit -m "feat(widget): add TramiteStatusBadge"
```

---

## Task 5: TramiteTimeline — Widget timeline de eventos

**Files:**
- Create: `lib/presentation/widgets/tramite_timeline.dart`

- [ ] **Step 1: Crear el widget**

```dart
// lib/presentation/widgets/tramite_timeline.dart
//
// Responsabilidad: renderizar la línea de tiempo de eventos de un trámite.
// Los eventos vienen del WebSocket STOMP en tiempo real.
// Cada tipo de evento tiene un ícono y mensaje descriptivo distinto.

import 'package:flutter/material.dart';
import '../../domain/models/tramite_event.dart';

/// Widget que muestra la línea de tiempo de eventos de un trámite.
///
/// Recibe [eventos] ordenados por timestamp ASC (el más antiguo primero).
/// Cada evento tiene ícono, color y descripción según su [eventType].
///
/// Tipos de evento soportados (según CONTEXTO_MOVIL.md §4):
/// NODE_ENTERED · TASK_COMPLETED · TASK_REJECTED · FORK_SPLIT ·
/// JOIN_SYNCHRONIZED · COMPLETED · CANCELLED
class TramiteTimeline extends StatelessWidget {
  /// Lista de eventos a mostrar, ordenados de más antiguo a más reciente.
  final List<TramiteEvent> eventos;

  const TramiteTimeline({super.key, required this.eventos});

  /// Devuelve ícono según el tipo de evento.
  IconData _icono(String eventType) {
    switch (eventType) {
      case 'NODE_ENTERED':
        return Icons.arrow_forward_ios;
      case 'TASK_COMPLETED':
        return Icons.check_circle_outline;
      case 'TASK_REJECTED':
        return Icons.cancel_outlined;
      case 'FORK_SPLIT':
        return Icons.call_split;
      case 'JOIN_SYNCHRONIZED':
        return Icons.merge_type;
      case 'COMPLETED':
        return Icons.verified;
      case 'CANCELLED':
        return Icons.block;
      default:
        return Icons.info_outline;
    }
  }

  /// Devuelve color del ícono según el tipo de evento.
  Color _color(String eventType) {
    switch (eventType) {
      case 'TASK_COMPLETED':
      case 'JOIN_SYNCHRONIZED':
      case 'COMPLETED':
        return const Color(0xFF4CAF50); // verde
      case 'TASK_REJECTED':
      case 'CANCELLED':
        return const Color(0xFFF44336); // rojo
      case 'NODE_ENTERED':
        return const Color(0xFF2196F3); // azul
      case 'FORK_SPLIT':
        return const Color(0xFF9C27B0); // púrpura (paralelismo)
      default:
        return const Color(0xFF9E9E9E); // gris
    }
  }

  /// Devuelve descripción legible del tipo de evento.
  String _descripcion(String eventType) {
    switch (eventType) {
      case 'NODE_ENTERED':
        return 'Trámite avanzó a un nuevo paso';
      case 'TASK_COMPLETED':
        return 'Paso completado';
      case 'TASK_REJECTED':
        return 'Paso rechazado — tomando flujo alternativo';
      case 'FORK_SPLIT':
        return 'Proceso paralelo iniciado';
      case 'JOIN_SYNCHRONIZED':
        return 'Pasos paralelos sincronizados';
      case 'COMPLETED':
        return 'Trámite finalizado exitosamente';
      case 'CANCELLED':
        return 'Trámite cancelado';
      default:
        return eventType;
    }
  }

  /// Formatea timestamp ISO 8601 a formato legible (HH:mm · dd/MM).
  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$hh:$mm · $dd/$mo';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'Esperando actualizaciones...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final evento = eventos[index];
        final esUltimo = index == eventos.length - 1;
        final color = _color(evento.eventType);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda: ícono + línea conectora
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Icon(_icono(evento.eventType), color: color, size: 22),
                    if (!esUltimo)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Columna derecha: descripción + timestamp + comentario
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _descripcion(evento.eventType),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(evento.timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (evento.comentario != null &&
                          evento.comentario!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          evento.comentario!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/tramite_timeline.dart
git commit -m "feat(widget): add TramiteTimeline with event icons and colors"
```

---

## Task 6: PoliticaCard — Widget tarjeta de política

**Files:**
- Create: `lib/presentation/widgets/politica_card.dart`

- [ ] **Step 1: Crear el widget**

```dart
// lib/presentation/widgets/politica_card.dart
//
// Responsabilidad: tarjeta visual para una política del catálogo.
// Muestra nombre y descripción. Toque opcional para ver detalle.

import 'package:flutter/material.dart';
import '../../domain/models/politica_model.dart';

/// Tarjeta que muestra el nombre y descripción de una [PoliticaModel].
///
/// Usada en [PoliticasScreen] dentro de un [ListView].
class PoliticaCard extends StatelessWidget {
  /// Política a mostrar.
  final PoliticaModel politica;

  /// Callback opcional al tocar la tarjeta (para ver detalle en el futuro).
  final VoidCallback? onTap;

  const PoliticaCard({super.key, required this.politica, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: Color(0xFF3F51B5), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      politica.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                politica.descripcion,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/politica_card.dart
git commit -m "feat(widget): add PoliticaCard"
```

---

## Task 7: PoliticasScreen — Pantalla catálogo de políticas

**Files:**
- Create: `lib/presentation/screens/politicas_screen.dart`

- [ ] **Step 1: Crear la pantalla**

```dart
// lib/presentation/screens/politicas_screen.dart
//
// Responsabilidad: mostrar el catálogo de políticas publicadas.
// Consume PoliticaCatalogProvider para el estado de carga.
// Ruta: / (pantalla inicial de la app)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/politica_catalog_provider.dart';
import '../widgets/politica_card.dart';

/// Pantalla que muestra el catálogo de políticas de negocio publicadas.
///
/// Llama a `GET /api/policies/public` al inicializarse.
/// Muestra lista scrollable de [PoliticaCard].
///
/// Ruta nombrada: `/`
class PoliticasScreen extends StatefulWidget {
  const PoliticasScreen({super.key});

  @override
  State<PoliticasScreen> createState() => _PoliticasScreenState();
}

class _PoliticasScreenState extends State<PoliticasScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar políticas al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticaCatalogProvider>().cargarPoliticas();
    });
  }

  /// Construye el cuerpo de la pantalla según el estado del provider.
  Widget _buildBody(PoliticaCatalogProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.cargarPoliticas,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (provider.politicas.isEmpty) {
      return const Center(
        child: Text(
          'No hay políticas disponibles por el momento.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.cargarPoliticas,
      child: ListView.builder(
        itemCount: provider.politicas.length,
        itemBuilder: (context, index) {
          return PoliticaCard(politica: provider.politicas[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Trámites'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      body: Consumer<PoliticaCatalogProvider>(
        builder: (context, provider, _) => _buildBody(provider),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/screens/politicas_screen.dart
git commit -m "feat(screen): add PoliticasScreen — catalog with loading/error/empty states"
```

---

## Task 8: SeguimientoScreen — Pantalla seguimiento con timeline

**⚠️ PUSH NOTIFICATION — Esta pantalla activa el registro FCM al buscar el ticket**

**Files:**
- Create: `lib/presentation/screens/seguimiento_screen.dart`

- [ ] **Step 1: Crear la pantalla**

```dart
// lib/presentation/screens/seguimiento_screen.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATION — SeguimientoScreen
// ══════════════════════════════════════════════════════════════════
// Esta pantalla activa el flujo completo de notificaciones push:
//   Al presionar "Buscar" → SeguimientoProvider.buscarTramite(ticket)
//     → registra FCM token en backend → el backend envía push cuando el
//       trámite avanza.
//
// También es el destino de navegación cuando el usuario toca una
// notificación push desde background/terminated (ver FcmService.setupTapHandler).
// ══════════════════════════════════════════════════════════════════
//
// Responsabilidad: input de ticket + estado del trámite + timeline.
// Ruta: /seguimiento (recibe ticketNumber opcional como argument)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seguimiento_provider.dart';
import '../widgets/tramite_status_badge.dart';
import '../widgets/tramite_timeline.dart';

/// Pantalla de seguimiento de trámite por número de ticket.
///
/// Flujo:
/// 1. Usuario ingresa [ticketNumber] y presiona "Buscar"
/// 2. [SeguimientoProvider] hace GET del estado + registra FCM + conecta WS
/// 3. Los eventos WebSocket actualizan el [TramiteTimeline] en tiempo real
///
/// ── PUSH NOTIFICATION ──
/// También se puede abrir desde una notificación push. En ese caso,
/// recibe el [ticketNumber] como `ModalRoute.of(context)?.settings.arguments`.
///
/// Ruta nombrada: `/seguimiento`
class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final TextEditingController _ticketController = TextEditingController();
  bool _initFromNotification = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initFromNotification) {
      // ── PUSH NOTIFICATION ── si la pantalla se abrió desde una notificación push,
      // el ticketNumber viene como argument de la ruta
      final ticketFromNotif =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (ticketFromNotif != null && ticketFromNotif.isNotEmpty) {
        _initFromNotification = true;
        _ticketController.text = ticketFromNotif;
        // Buscar automáticamente al abrir desde notificación
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buscar(ticketFromNotif);
        });
      }
    }
  }

  @override
  void dispose() {
    _ticketController.dispose();
    // El provider se encarga de desconectar el WebSocket en su propio dispose
    super.dispose();
  }

  /// Inicia la búsqueda del trámite por ticket.
  ///
  /// Llama a [SeguimientoProvider.buscarTramite] que:
  /// 1. GET estado inicial
  /// 2. POST fcm-token al backend  ← ACTIVA PUSH NOTIFICATIONS
  /// 3. WS suscripción en tiempo real
  void _buscar(String ticket) {
    final trimmed = ticket.trim();
    if (trimmed.isEmpty) return;
    context.read<SeguimientoProvider>().buscarTramite(trimmed);
  }

  /// Construye el campo de búsqueda de ticket.
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Número de Ticket',
                hintText: 'Ej: TRM-2026-0042',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _buscar,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _buscar(_ticketController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  /// Construye el contenido según el estado del [SeguimientoProvider].
  Widget _buildContent(SeguimientoProvider provider) {
    switch (provider.estado) {
      case SeguimientoEstado.inicial:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Ingresa tu número de ticket\npara ver el estado de tu trámite',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        );

      case SeguimientoEstado.cargando:
        return const Center(child: CircularProgressIndicator());

      case SeguimientoEstado.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );

      case SeguimientoEstado.activo:
      case SeguimientoEstado.completado:
        final tramite = provider.tramite!;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de estado del trámite
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tramite.ticketNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TramiteStatusBadge(status: tramite.status),
                        ],
                      ),
                      if (tramite.startedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Iniciado: ${tramite.startedAt}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (tramite.completedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Finalizado: ${tramite.completedAt}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Línea de tiempo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // ── PUSH NOTIFICATION ── Los eventos aquí son los mismos que
              // disparan las push notifications desde el backend.
              // El WebSocket los recibe en tiempo real; las push llegan
              // cuando la app está en background.
              TramiteTimeline(eventos: provider.eventos),
              if (provider.eventos.isEmpty &&
                  provider.estado == SeguimientoEstado.activo)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Conectado. Esperando eventos en tiempo real...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Trámite'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildBuscador(),
          const Divider(height: 1),
          Expanded(
            child: Consumer<SeguimientoProvider>(
              builder: (context, provider, _) => _buildContent(provider),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/screens/seguimiento_screen.dart
git commit -m "feat(screen): add SeguimientoScreen — ticket search, timeline, WS updates"
```

---

## Task 9: app.dart — MaterialApp con rutas, providers y FCM

**⚠️ PUSH NOTIFICATION — Aquí se configuran foreground handler y tap handler**

**Files:**
- Create: `lib/app.dart`

- [ ] **Step 1: Crear app.dart**

```dart
// lib/app.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATION — App root
// ══════════════════════════════════════════════════════════════════
// Aquí se inicializan:
//   - FcmService.setupForegroundHandler() → notifs con app abierta
//   - FcmService.setupTapHandler()        → navegación desde notif push
//
// El background handler está en main.dart (función top-level obligatoria).
// ══════════════════════════════════════════════════════════════════
//
// Responsabilidad: configurar MaterialApp, rutas nombradas y MultiProvider.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/fcm_service.dart';
import 'presentation/providers/politica_catalog_provider.dart';
import 'presentation/providers/seguimiento_provider.dart';
import 'presentation/screens/politicas_screen.dart';
import 'presentation/screens/seguimiento_screen.dart';

/// Widget raíz de la aplicación.
///
/// Configura [MultiProvider] con los providers globales y
/// [MaterialApp] con rutas nombradas.
///
/// ── PUSH NOTIFICATION ──
/// Inicializa [FcmService] en [initState] para configurar handlers
/// de notificaciones en foreground y tap desde background/terminated.
class BpmClientApp extends StatefulWidget {
  const BpmClientApp({super.key});

  @override
  State<BpmClientApp> createState() => _BpmClientAppState();
}

class _BpmClientAppState extends State<BpmClientApp> {
  // ── PUSH NOTIFICATION ── key global para navegar desde notificaciones
  // sin necesitar un BuildContext activo
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ── PUSH NOTIFICATION ── servicio FCM centralizado
  final FcmService _fcmService = FcmService();

  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  /// Inicializa los handlers de notificaciones push.
  ///
  /// ── PUSH NOTIFICATION ── llamado una sola vez al arrancar la app.
  Future<void> _initFcm() async {
    // ── PUSH NOTIFICATION ── handler para mensajes recibidos con app abierta
    _fcmService.setupForegroundHandler(
      onMessage: (message) {
        // Mostrar un SnackBar cuando llega una notif y la app está abierta
        final title = message.notification?.title ?? 'Actualización';
        final body = message.notification?.body ?? '';
        _navigatorKey.currentState?.overlay?.context.let((ctx) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('$title: $body')),
          );
        });
      },
    );

    // ── PUSH NOTIFICATION ── handler para cuando usuario toca la notif
    // (background o app terminada) → navega a /seguimiento con ticketNumber
    _fcmService.setupTapHandler(_navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PoliticaCatalogProvider()),
        // ── PUSH NOTIFICATION ── SeguimientoProvider recibe FcmService
        // para obtener el token y registrarlo en el backend
        ChangeNotifierProvider(
          create: (_) => SeguimientoProvider(_fcmService),
        ),
      ],
      child: MaterialApp(
        title: 'BPM — Consulta de Trámites',
        navigatorKey: _navigatorKey, // ← necesario para navegación desde push
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        // Rutas nombradas
        initialRoute: '/',
        routes: {
          '/': (_) => const PoliticasScreen(),
          // ── PUSH NOTIFICATION ── ruta destino al tocar notif push
          '/seguimiento': (_) => const SeguimientoScreen(),
        },
      ),
    );
  }
}

// Extensión utilitaria para operaciones sobre contexto nullable
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/app.dart
git commit -m "feat(app): add BpmClientApp — routes, MultiProvider, FCM handlers"
```

---

## Task 10: Refactor main.dart — Background FCM handler + llamar app.dart

**⚠️ PUSH NOTIFICATION — El background handler DEBE ser función top-level aquí**

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Reemplazar contenido de main.dart**

```dart
// lib/main.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATION — Background Handler (OBLIGATORIO en main.dart)
// ══════════════════════════════════════════════════════════════════
// fcmBackgroundHandler DEBE ser una función top-level (no dentro de
// ninguna clase). Firebase la invoca en un isolate separado cuando
// la app está en background o terminada.
//
// RESTRICCIÓN: no puede acceder a contexto de Flutter ni a providers.
// Solo persistencia local (shared_preferences, hive) si es necesario.
// ══════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app.dart';

// ── PUSH NOTIFICATION ── handler de mensajes en background/terminated
// Función top-level obligatoria — no mover dentro de ninguna clase
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el isolate del background handler
  await Firebase.initializeApp();
  debugPrint(
    '[FCM Background] evento: ${message.data['eventType']} | '
    'ticket: ${message.data['ticketNumber']}',
  );
  // No navegar aquí — la navegación ocurre en FcmService.setupTapHandler()
  // cuando el usuario toca la notificación
}

/// Punto de entrada de la aplicación Flutter.
///
/// Inicializa Firebase, registra el background handler de FCM y
/// lanza [BpmClientApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase (requerido antes de cualquier uso de FCM)
  await Firebase.initializeApp();

  // ── PUSH NOTIFICATION ── registrar handler de background ANTES de runApp
  FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

  runApp(const BpmClientApp());
}
```

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/
```

Expected: No issues (o solo warnings menores).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "refactor(main): FCM background handler top-level, delegate to BpmClientApp"
```

---

## Resumen de la estructura final

```
lib/
├── app.dart                                          ← NEW: MaterialApp + MultiProvider + FCM handlers
├── main.dart                                         ← MOD: background FCM handler top-level
├── core/
│   ├── constants/api_constants.dart                  (sin cambios)
│   ├── network/stomp_client_config.dart              (sin cambios)
│   └── services/
│       └── fcm_service.dart                          ← NEW ⚠️ PUSH
├── data/                                             (sin cambios)
├── domain/                                           (sin cambios)
└── presentation/
    ├── providers/
    │   ├── politica_catalog_provider.dart            ← NEW
    │   └── seguimiento_provider.dart                 ← NEW ⚠️ PUSH (registra token FCM)
    ├── screens/
    │   ├── politicas_screen.dart                     ← NEW
    │   └── seguimiento_screen.dart                   ← NEW ⚠️ PUSH (destino de notif)
    └── widgets/
        ├── politica_card.dart                        ← NEW
        ├── tramite_status_badge.dart                 ← NEW
        └── tramite_timeline.dart                     ← NEW
```

## ⏱ Timeline Push — Resumen visual

```
ARCHIVO                          QUÉ HACE CON PUSH
─────────────────────────────────────────────────────────────────
main.dart                        fcmBackgroundHandler (top-level, isolate separado)
core/services/fcm_service.dart   requestPermission, getToken, foreground+tap handlers
presentation/providers/
  seguimiento_provider.dart      _registrarFcmToken → POST /fcm-token al backend
presentation/screens/
  seguimiento_screen.dart        didChangeDependencies lee ticketNumber de route args
app.dart                         navigatorKey global, setupForegroundHandler, setupTapHandler
```
