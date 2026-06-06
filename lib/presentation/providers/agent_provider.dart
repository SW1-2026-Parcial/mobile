import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/database/local_database.dart';
import '../../core/database/sync/sync_queue.dart';
import '../../core/database/sync/connectivity_service.dart';
import '../../data/repositories/agent_repository.dart';
import '../../domain/models/mensaje_agente.dart';

/// Provider que gestiona el estado de la conversación con el agente.
class AgentProvider extends ChangeNotifier {
  final AgentRepository _repository = AgentRepository();
  final ConnectivityService _connectivity;

  List<MensajeAgente> _mensajes = [];
  bool _isLoading = false;
  String? _error;

  List<MensajeAgente> get mensajes => _mensajes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Campos recopilados hasta ahora en la conversación.
  Map<String, dynamic>? get camposRecopilados {
    for (int i = _mensajes.length - 1; i >= 0; i--) {
      if (!_mensajes[i].esUsuario && _mensajes[i].camposRecopilados != null) {
        return _mensajes[i].camposRecopilados;
      }
    }
    return null;
  }

  /// Campos que faltan por completar.
  List<String>? get camposFaltantes {
    for (int i = _mensajes.length - 1; i >= 0; i--) {
      if (!_mensajes[i].esUsuario && _mensajes[i].camposFaltantes != null) {
        return _mensajes[i].camposFaltantes;
      }
    }
    return null;
  }

  /// Si el agente indica que se puede iniciar el trámite.
  bool get listoParaIniciar {
    for (int i = _mensajes.length - 1; i >= 0; i--) {
      if (!_mensajes[i].esUsuario && _mensajes[i].listoParaIniciar) {
        return true;
      }
    }
    return false;
  }

  AgentProvider(this._connectivity) {
    _cargarConversacionLocal();
  }

  /// Envía un mensaje al agente (online u offline).
  Future<void> enviarMensaje(String texto) async {
    _error = null;

    // Agregar mensaje del usuario localmente
    final msgUsuario = MensajeAgente(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contenido: texto,
      esUsuario: true,
      timestamp: DateTime.now(),
    );
    _mensajes.add(msgUsuario);
    _isLoading = true;
    notifyListeners();

    if (!_connectivity.isOnline) {
      // Offline: encolar acción y guardar localmente
      await SyncQueue.enqueue(PendingAction(
        id: 'agent_${msgUsuario.id}',
        method: 'POST',
        endpoint: '/agent/chat',
        body: {'mensaje': texto, 'sessionId': _repository.sessionId},
        createdAt: DateTime.now(),
      ));

      final offlineReply = MensajeAgente(
        id: '${DateTime.now().millisecondsSinceEpoch}_offline',
        contenido: 'Sin conexión. Tu mensaje se enviará cuando vuelvas a estar en línea.',
        esUsuario: false,
        timestamp: DateTime.now(),
      );
      _mensajes.add(offlineReply);
      _isLoading = false;
      _guardarConversacionLocal();
      notifyListeners();
      return;
    }

    try {
      final respuesta = await _repository.enviarMensaje(texto);
      _mensajes.add(respuesta);
    } catch (e) {
      _error = 'Error al comunicarse con el agente';
      final errorMsg = MensajeAgente(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        contenido: 'Error de conexión. Intenta nuevamente.',
        esUsuario: false,
        timestamp: DateTime.now(),
      );
      _mensajes.add(errorMsg);
    } finally {
      _isLoading = false;
      _guardarConversacionLocal();
      notifyListeners();
    }
  }

  /// Inicia una nueva conversación limpia.
  Future<void> nuevaConversacion() async {
    await _repository.limpiarSesion();
    _mensajes = [];
    _error = null;
    await LocalDatabase.conversaciones.delete('current');
    notifyListeners();
  }

  void _guardarConversacionLocal() {
    final data = _mensajes.map((m) => m.toJson()).toList();
    LocalDatabase.conversaciones.put('current', jsonEncode(data));
  }

  void _cargarConversacionLocal() {
    final raw = LocalDatabase.conversaciones.get('current');
    if (raw != null) {
      final List<dynamic> data = jsonDecode(raw);
      _mensajes = data.map((d) => MensajeAgente.fromJson(d)).toList();
    }
  }
}
