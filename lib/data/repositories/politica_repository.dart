import 'dart:convert';
import '../providers/tramite_provider.dart';
import '../../domain/models/politica_model.dart';

class PoliticaRepository {
  final TramiteProvider _provider = TramiteProvider();

  // Obtiene la lista de políticas publicadas (PUBLISHED)
  Future<List<PoliticaModel>> obtenerCatalogoPublico() async {
    final response = await _provider.getPublicPolicies(); // Llama al endpoint de la ADR-019
    
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      // Convertimos cada JSON de la lista en un objeto PoliticaModel
      return data.map((json) => PoliticaModel.fromJson(json)).toList();
    } else {
      throw Exception("Error al cargar el catálogo de trámites");
    }
  }
}