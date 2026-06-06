import 'package:flutter/material.dart';
import '../../core/network/stomp_client_config.dart';
import '../../data/repositories/tramite_repository.dart';
import '../../domain/models/tramite_event.dart';
import '../../domain/models/tramite_model.dart';
import '../../domain/service/tramite_services.dart';

enum SeguimientoEstado { inicial, cargando, activo, completado, error }

class SeguimientoProvider extends ChangeNotifier {
  final TramiteRepository _repository = TramiteRepository();
  final StompClientConfig _stompConfig = StompClientConfig();
  final TramiteService _tramiteService = TramiteService();

  TramiteModel? tramite;
  List<TramiteEvent> eventos = [];
  SeguimientoEstado estado = SeguimientoEstado.inicial;
  String? errorMessage;

  Future<void> buscarTramite(String ticketNumber) async {
    estado = SeguimientoEstado.cargando;
    errorMessage = null;
    eventos = [];
    notifyListeners();

    try {
      tramite = await _repository.obtenerEstadoActual(ticketNumber);

      final terminado = tramite!.status == TramiteStatus.COMPLETED ||
          tramite!.status == TramiteStatus.REJECTED;

      estado = terminado ? SeguimientoEstado.completado : SeguimientoEstado.activo;

      // Solo abrir WS si el trámite sigue activo — inútil escuchar uno terminado.
      if (!terminado) {
        _conectarWebSocket(tramite!.id);
      }
    } catch (e) {
      errorMessage = 'No se encontró el trámite. Verifica el número de ticket.';
      estado = SeguimientoEstado.error;
      debugPrint('[SeguimientoProvider] Error en buscarTramite: $e');
    }

    notifyListeners();
  }

  void _conectarWebSocket(String tramiteId) {
    _stompConfig.connect(
      tramiteId,
      (data) {
        final evento = TramiteEvent.fromJson(data);
        eventos.add(evento);
        _tramiteService.ordenarEventosPorFecha(eventos);

        if (evento.eventType == 'COMPLETED' || evento.eventType == 'CANCELLED') {
          estado = SeguimientoEstado.completado;
        }

        notifyListeners();
      },
      onDisconnected: () {
        // WS perdido definitivamente (reintentos agotados) — avisar en UI
        // pero no cambiar estado: el último estado conocido sigue siendo válido.
        errorMessage = 'Conexión en tiempo real perdida. Recarga para actualizar.';
        notifyListeners();
      },
    );
  }

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
