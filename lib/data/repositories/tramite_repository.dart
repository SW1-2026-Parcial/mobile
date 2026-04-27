import 'dart:convert';
import '../providers/tramite_provider.dart';
import '../../domain/models/tramite_model.dart';

class TramiteRepository {
  final TramiteProvider _provider = TramiteProvider();

  Future<TramiteModel> obtenerEstadoActual(String ticket) async {
    final response = await _provider.getTramiteByTicket(ticket);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TramiteModel.fromJson(data);
    } else {
      throw Exception(
        'Error al obtener estado del trámite: ${response.statusCode}',
      );
    }
  }
}
