import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/stomp_client_config.dart';
import '../../core/services/local_notification_service.dart';
import '../../data/repositories/tramite_repository.dart';
import '../../domain/models/tramite_event.dart';
import '../../domain/models/tramite_model.dart';
import '../../domain/service/tramite_services.dart';

enum SeguimientoEstado { inicial, cargando, activo, completado, error }

class SeguimientoProvider extends ChangeNotifier {
  final TramiteRepository _repository = TramiteRepository();
  final StompClientConfig _stompConfig = StompClientConfig();
  final TramiteService _tramiteService = TramiteService();

  final LocalNotificationService _localNotificationService;

  SeguimientoProvider(this._localNotificationService);

  TramiteModel? tramite;
  List<TramiteEvent> eventos = [];
  SeguimientoEstado estado = SeguimientoEstado.inicial;
  String? errorMessage;

  // ── Polling ──
  Timer? _pollingTimer;
  List<String> _lastNodeIds = [];
  TramiteStatus? _lastStatus;
  String? _ticketActivo;
  static const int _pollingIntervalSec = 10;

  // ─────────────────────────────────────────────────────────────────
  // Paso 1: Buscar trámite por ticketNumber
  // ─────────────────────────────────────────────────────────────────

  Future<void> buscarTramite(String ticketNumber) async {
    estado = SeguimientoEstado.cargando;
    errorMessage = null;
    eventos = [];
    _stopPolling();
    notifyListeners();

    try {
      tramite = await _repository.obtenerEstadoActual(ticketNumber);

      _ticketActivo = ticketNumber;
      _lastNodeIds = List<String>.from(tramite!.currentNodeIds);
      _lastStatus = tramite!.status;

      _conectarWebSocket(tramite!.id);

      estado = tramite!.status == TramiteStatus.COMPLETED ||
              tramite!.status == TramiteStatus.REJECTED
          ? SeguimientoEstado.completado
          : SeguimientoEstado.activo;

      if (estado == SeguimientoEstado.activo) {
        _startPolling();
      }
    } catch (e) {
      errorMessage = 'No se encontró el trámite. Verifica el número de ticket.';
      estado = SeguimientoEstado.error;
      debugPrint('[SeguimientoProvider] Error en buscarTramite: $e');
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Polling — consulta periódica al backend
  // ─────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: _pollingIntervalSec),
      (_) => _pollAndNotify(),
    );
    debugPrint('[Polling] Iniciado cada $_pollingIntervalSec s para $_ticketActivo');
  }

  Future<void> _pollAndNotify() async {
    if (_ticketActivo == null) return;

    TramiteModel nuevo;
    try {
      nuevo = await _repository.obtenerEstadoActual(_ticketActivo!);
    } catch (e) {
      debugPrint('[Polling] Error al consultar backend: $e');
      return;
    }

    final statusCambio = nuevo.status != _lastStatus;
    final nodosCambio = !_listasIguales(nuevo.currentNodeIds, _lastNodeIds);

    if (statusCambio || nodosCambio) {
      final titulo = _tituloNotif(nuevo.status, statusCambio);
      final cuerpo = _cuerpoNotif(nuevo.status, statusCambio);

      await _localNotificationService.showTramiteUpdate(
        titulo: titulo,
        cuerpo: cuerpo,
      );

      tramite = nuevo;
      _lastStatus = nuevo.status;
      _lastNodeIds = List<String>.from(nuevo.currentNodeIds);

      if (nuevo.status == TramiteStatus.COMPLETED ||
          nuevo.status == TramiteStatus.REJECTED) {
        estado = SeguimientoEstado.completado;
        _stopPolling();
      }

      notifyListeners();
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  bool _listasIguales(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _tituloNotif(TramiteStatus status, bool statusCambio) {
    if (statusCambio && status == TramiteStatus.COMPLETED) {
      return 'Trámite finalizado ✓';
    }
    if (statusCambio && status == TramiteStatus.REJECTED) {
      return 'Trámite rechazado';
    }
    return 'Trámite actualizado';
  }

  String _cuerpoNotif(TramiteStatus status, bool statusCambio) {
    if (statusCambio && status == TramiteStatus.COMPLETED) {
      return 'Tu trámite $_ticketActivo ha sido completado';
    }
    if (statusCambio && status == TramiteStatus.REJECTED) {
      return 'Tu trámite $_ticketActivo fue rechazado';
    }
    return 'Tu trámite $_ticketActivo avanzó a una nueva etapa';
  }

  // ─────────────────────────────────────────────────────────────────
  // WebSocket STOMP
  // ─────────────────────────────────────────────────────────────────

  void _conectarWebSocket(String tramiteId) {
    _stompConfig.connect(tramiteId, (data) {
      final evento = TramiteEvent.fromJson(data);
      eventos.add(evento);
      _tramiteService.ordenarEventosPorFecha(eventos);

      if (evento.eventType == 'COMPLETED' || evento.eventType == 'CANCELLED') {
        estado = SeguimientoEstado.completado;
      }

      notifyListeners();
    });
  }

  void desconectar() {
    try {
      _stompConfig.disconnect();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopPolling();
    desconectar();
    super.dispose();
  }
}
