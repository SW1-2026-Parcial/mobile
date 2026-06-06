import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/database/local_database.dart';
import '../../domain/models/mensaje_agente.dart';

/// Repositorio para comunicación con el agente conversacional del backend.
/// El endpoint /api/agent/chat es público — no requiere JWT.
///
/// El sessionId se persiste en Hive (LocalDatabase.config) para que sobreviva
/// reinicios de la app y el agente conserve el contexto de la conversación.
class AgentRepository {
  static const String _sessionIdKey = 'agentSessionId';

  String? _sessionId;

  AgentRepository() {
    // Recuperar sessionId guardado en sesiones anteriores
    _sessionId = LocalDatabase.config.get(_sessionIdKey) as String?;
  }

  String? get sessionId => _sessionId;

  /// Envía un mensaje al agente y retorna la respuesta estructurada.
  Future<MensajeAgente> enviarMensaje(String mensaje) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/agent/chat');

    final body = <String, dynamic>{
      'mensaje': mensaje,
    };
    if (_sessionId != null) {
      body['sessionId'] = _sessionId!;
    }

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _sessionId = data['sessionId'];
      // Persistir para que sobreviva reinicios de la app
      if (_sessionId != null) {
        await LocalDatabase.config.put(_sessionIdKey, _sessionId!);
      }

      return MensajeAgente(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        contenido: data['mensaje'] ?? '',
        esUsuario: false,
        timestamp: DateTime.now(),
        politicaIdentificada: data['politicaIdentificada'],
        camposRecopilados: data['camposRecopilados'] != null
            ? Map<String, dynamic>.from(data['camposRecopilados'])
            : null,
        camposFaltantes: data['camposFaltantes'] != null
            ? List<String>.from(data['camposFaltantes'])
            : null,
        listoParaIniciar: data['listoParaIniciar'] ?? false,
      );
    } else {
      throw Exception('Error del agente: ${response.statusCode}');
    }
  }

  /// Limpia la sesión actual del agente.
  Future<void> limpiarSesion() async {
    if (_sessionId == null) return;

    await http.post(
      Uri.parse('${ApiConstants.baseUrl}/agent/clear-session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionId': _sessionId, 'mensaje': ''}),
    );

    _sessionId = null;
    await LocalDatabase.config.delete(_sessionIdKey);
  }
}
