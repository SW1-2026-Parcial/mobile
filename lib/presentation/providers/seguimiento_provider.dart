import 'package:flutter/material.dart';
import '../../core/network/stomp_client_config.dart';
import '../../core/services/fcm_service.dart';
import '../../data/repositories/tramite_repository.dart';
import '../../domain/models/tramite_event.dart';
import '../../domain/models/tramite_model.dart';
import '../../domain/service/tramite_services.dart';

enum SeguimientoEstado { inicial, cargando, activo, completado, error }

class SeguimientoProvider extends ChangeNotifier {
  final TramiteRepository _repository = TramiteRepository();
  final StompClientConfig _stompConfig = StompClientConfig();
  final TramiteService _tramiteService = TramiteService();

  final FcmService _fcmService;

  SeguimientoProvider(this._fcmService);

  TramiteModel? tramite;

  List<TramiteEvent> eventos = [];

  SeguimientoEstado estado = SeguimientoEstado.inicial;

  String? errorMessage;

  // ─────────────────────────────────────────────────────────────────
  // Paso 1: Buscar trámite por ticketNumber
  // ─────────────────────────────────────────────────────────────────

  Future<void> buscarTramite(String ticketNumber) async {
    estado = SeguimientoEstado.cargando;
    errorMessage = null;
    eventos = [];
    notifyListeners();

    try {
      tramite = await _repository.obtenerEstadoActual(ticketNumber);

      await _registrarFcmToken(ticketNumber);

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
