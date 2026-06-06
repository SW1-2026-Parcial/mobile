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
      final msg = e.toString();
      errorMessage = msg.contains('caché')
          ? 'Sin conexión y sin datos guardados. Conéctate para ver el catálogo.'
          : 'No se pudo cargar el catálogo. Intenta de nuevo.';
      debugPrint('[PoliticaCatalogProvider] Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
