import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

/// Cliente WebSocket puro para el canal de trámites en tiempo real.
/// NOTA: el nombre "Stomp" es histórico — el backend expone WS puro en /ws/tramites/{id}.
///
/// Reconexión automática: si la conexión se corta inesperadamente (onError/onDone)
/// reintenta cada [_reconnectDelaySec] segundos hasta [_maxReconnectAttempts] veces.
class StompClientConfig {
  static const int _reconnectDelaySec   = 5;
  static const int _maxReconnectAttempts = 5;

  WebSocketChannel? _channel;
  String?           _tramiteId;
  Function(Map<String, dynamic>)? _onEventReceived;
  VoidCallback?     _onDisconnected;       // notifica a la UI cuando WS se pierde definitivamente

  bool _intentionalClose = false;          // true cuando llamamos disconnect() nosotros
  int  _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Conecta al canal WS de [tramiteId].
  /// - [onEventReceived]  → llamado con cada payload JSON del servidor
  /// - [onDisconnected]   → llamado si la conexión se pierde y ya se agotaron los reintentos
  void connect(
    String tramiteId,
    Function(Map<String, dynamic>) onEventReceived, {
    VoidCallback? onDisconnected,
  }) {
    _tramiteId        = tramiteId;
    _onEventReceived  = onEventReceived;
    _onDisconnected   = onDisconnected;
    _intentionalClose = false;
    _reconnectAttempts = 0;
    _openChannel();
  }

  void _openChannel() {
    final wsUrl = '${ApiConstants.wsUrl}/tramites/$_tramiteId';
    debugPrint('[WS] Conectando a $wsUrl (intento $_reconnectAttempts)');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      debugPrint('[WS] Error al abrir canal: $e');
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0; // reset al recibir datos exitosamente
        try {
          final data = jsonDecode(message as String);
          _onEventReceived?.call(data);
        } catch (e) {
          debugPrint('[WS] Error al parsear mensaje: $e');
        }
      },
      onError: (error) {
        debugPrint('[WS] Error en canal: $error');
        if (!_intentionalClose) _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[WS] Canal cerrado');
        if (!_intentionalClose) _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Máximo de reintentos alcanzado. Notificando UI.');
      _onDisconnected?.call();
      return;
    }
    _reconnectAttempts++;
    debugPrint('[WS] Reintento $_reconnectAttempts en ${_reconnectDelaySec}s...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: _reconnectDelaySec), _openChannel);
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }
}
