import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';
import '../local_database.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';

/// Servicio de sincronización que push/pull datos cuando la conexión se recupera.
class SyncService {
  final ConnectivityService _connectivity;
  bool _isSyncing = false;

  SyncService(this._connectivity) {
    _connectivity.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (_connectivity.isOnline && !_isSyncing) {
      syncAll();
    }
  }

  /// Ejecuta la sincronización completa: push pendientes, luego pull actualizaciones.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _pushPendingActions();
      await _pullUpdates();
      LocalDatabase.lastSync = DateTime.now();
    } catch (e) {
      debugPrint('[SyncService] Error en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Cabeceras base para peticiones HTTP.
  /// ADR-006: esta app es ciudadana — todos los endpoints accesibles son públicos.
  /// Si en el futuro se agrega autenticación, leer el token de LocalDatabase.config
  /// y agregarlo aquí como 'Authorization': 'Bearer $token'.
  Map<String, String> get _baseHeaders => const {
    'Content-Type': 'application/json',
  };

  /// Envía las acciones pendientes al servidor en orden FIFO.
  Future<void> _pushPendingActions() async {
    final actions = SyncQueue.getAll();
    if (actions.isEmpty) return;

    for (final action in actions) {
      try {
        final uri = Uri.parse('${ApiConstants.baseUrl}${action.endpoint}');
        http.Response response;

        switch (action.method) {
          case 'POST':
            response = await http.post(
              uri,
              headers: _baseHeaders,
              body: action.body != null ? jsonEncode(action.body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: _baseHeaders,
              body: action.body != null ? jsonEncode(action.body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: _baseHeaders);
            break;
          default:
            continue;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await SyncQueue.remove(action.id);
        }
      } catch (e) {
        debugPrint('[SyncService] Error al enviar acción ${action.id}: $e');
        break; // Detener si falla — mantener orden FIFO
      }
    }
  }

  /// Descarga actualizaciones del servidor desde el último timestamp.
  Future<void> _pullUpdates() async {
    try {
      final lastSync = LocalDatabase.lastSync;
      final queryParam = lastSync != null ? '?since=${lastSync.toIso8601String()}' : '';

      // Pull políticas públicas
      final polRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.publicPolicies}$queryParam'),
      );

      if (polRes.statusCode == 200) {
        final List<dynamic> politicas = jsonDecode(polRes.body);
        for (final pol in politicas) {
          await LocalDatabase.politicas.put(pol['id'], jsonEncode(pol));
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Error en pull: $e');
    }
  }

  void dispose() {
    _connectivity.removeListener(_onConnectivityChange);
  }
}
