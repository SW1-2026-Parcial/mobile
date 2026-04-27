import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/local_notification_service.dart';
import '../../data/repositories/tramite_repository.dart';
import '../../domain/models/tramite_model.dart';

class TramiteTrackerProvider extends ChangeNotifier {
  static const int maxTramites = 3;
  static const int _pollingIntervalSec = 10;

  final LocalNotificationService _localNotif;
  final TramiteRepository _repository = TramiteRepository();

  final Map<String, TramiteModel> _tracked = {};
  final Map<String, List<String>> _lastNodeIds = {};
  final Map<String, TramiteStatus> _lastStatus = {};
  Timer? _timer;

  TramiteTrackerProvider(this._localNotif);

  List<TramiteModel> get tramites => _tracked.values.toList();
  bool get estaLleno => _tracked.length >= maxTramites;

  void agregar(TramiteModel tramite) {
    if (_tracked.containsKey(tramite.ticketNumber)) return;
    if (estaLleno) return;

    _tracked[tramite.ticketNumber] = tramite;
    _lastNodeIds[tramite.ticketNumber] = List<String>.from(tramite.currentNodeIds);
    _lastStatus[tramite.ticketNumber] = tramite.status;

    if (_timer == null) _startTimer();
    notifyListeners();
  }

  void remover(String ticketNumber) {
    _tracked.remove(ticketNumber);
    _lastNodeIds.remove(ticketNumber);
    _lastStatus.remove(ticketNumber);

    if (_tracked.isEmpty) _stopTimer();
    notifyListeners();
  }

  bool contiene(String ticketNumber) => _tracked.containsKey(ticketNumber);

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: _pollingIntervalSec),
      (_) => _pollAll(),
    );
    debugPrint('[Tracker] Timer iniciado para ${_tracked.length} trámite(s)');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[Tracker] Timer cancelado');
  }

  Future<void> _pollAll() async {
    bool huboCambio = false;

    for (final ticket in List<String>.from(_tracked.keys)) {
      final lastStatus = _lastStatus[ticket];
      if (lastStatus == TramiteStatus.COMPLETED ||
          lastStatus == TramiteStatus.REJECTED) {
        continue; // ya finalizado, no pollear
      }

      TramiteModel nuevo;
      try {
        nuevo = await _repository.obtenerEstadoActual(ticket);
      } catch (e) {
        debugPrint('[Tracker] Error al consultar $ticket: $e');
        continue;
      }

      final statusCambio = nuevo.status != _lastStatus[ticket];
      final nodosCambio = !_listasIguales(
        nuevo.currentNodeIds,
        _lastNodeIds[ticket] ?? [],
      );

      if (statusCambio || nodosCambio) {
        await _localNotif.showTramiteUpdate(
          titulo: _titulo(nuevo.status, statusCambio),
          cuerpo: _cuerpo(ticket, nuevo.status, statusCambio),
        );

        _tracked[ticket] = nuevo;
        _lastStatus[ticket] = nuevo.status;
        _lastNodeIds[ticket] = List<String>.from(nuevo.currentNodeIds);
        huboCambio = true;
      }
    }

    // Cancelar timer si ya no quedan trámites activos
    final hayActivos = _lastStatus.values.any(
      (s) => s == TramiteStatus.ACTIVE || s == TramiteStatus.PAUSED,
    );
    if (!hayActivos) _stopTimer();

    if (huboCambio) notifyListeners();
  }

  bool _listasIguales(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _titulo(TramiteStatus status, bool statusCambio) {
    if (statusCambio && status == TramiteStatus.COMPLETED) return 'Trámite finalizado ✓';
    if (statusCambio && status == TramiteStatus.REJECTED) return 'Trámite rechazado';
    return 'Trámite actualizado';
  }

  String _cuerpo(String ticket, TramiteStatus status, bool statusCambio) {
    if (statusCambio && status == TramiteStatus.COMPLETED) {
      return 'Tu trámite $ticket ha sido completado';
    }
    if (statusCambio && status == TramiteStatus.REJECTED) {
      return 'Tu trámite $ticket fue rechazado';
    }
    return 'Tu trámite $ticket avanzó a una nueva etapa';
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
