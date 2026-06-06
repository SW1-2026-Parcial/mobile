import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../providers/tramite_provider.dart';
import '../../core/database/local_database.dart';
import '../../domain/models/politica_model.dart';

class PoliticaRepository {
  final TramiteProvider _provider = TramiteProvider();

  /// Obtiene catálogo de políticas publicadas (ADR-019).
  /// Estrategia network-first con fallback a caché Hive:
  ///   1. Intenta fetch desde el backend
  ///   2. Si OK → guarda en Hive y retorna
  ///   3. Si falla (offline / error) → lee Hive, retorna caché o lanza error
  Future<List<PoliticaModel>> obtenerCatalogoPublico() async {
    try {
      final response = await _provider.getPublicPolicies();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final politicas = data.map((json) => PoliticaModel.fromJson(json)).toList();

        // Guardar en caché local para uso offline
        _guardarEnHive(data);

        return politicas;
      } else {
        throw Exception('Error al cargar catálogo: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PoliticaRepository] Red no disponible, leyendo caché: $e');
      return _leerDesdeHive();
    }
  }

  void _guardarEnHive(List<dynamic> data) {
    try {
      for (final pol in data) {
        LocalDatabase.politicas.put(pol['id'], jsonEncode(pol));
      }
    } catch (e) {
      debugPrint('[PoliticaRepository] Error al guardar en Hive: $e');
    }
  }

  List<PoliticaModel> _leerDesdeHive() {
    final box = LocalDatabase.politicas;
    if (box.isEmpty) {
      throw Exception('Sin conexión y sin datos en caché.');
    }

    final politicas = <PoliticaModel>[];
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw != null) {
          politicas.add(PoliticaModel.fromJson(jsonDecode(raw)));
        }
      } catch (_) {}
    }
    return politicas;
  }
}