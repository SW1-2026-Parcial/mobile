import 'package:flutter/material.dart';
import '../../data/repositories/politica_repository.dart';
import '../../domain/models/politica_model.dart';


class PoliticaCatalogProvider extends ChangeNotifier {
  final PoliticaRepository _repository = PoliticaRepository();

  List<PoliticaModel> politicas = [];

  bool isLoading = false;

  String? errorMessage;

  Future<void> cargarPoliticas() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      politicas = await _repository.obtenerCatalogoPublico();
    } catch (e) {
      errorMessage = 'No se pudo cargar el catálogo de políticas. Intenta de nuevo.';
      debugPrint('[PoliticaCatalogProvider] Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
