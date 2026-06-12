import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../domain/models/documento_model.dart';

/// Repositorio de documentos — CRUD contra /api/documentos.
class DocumentoRepository {
  /// Lista documentos de un trámite por ID.
  Future<List<DocumentoModel>> getByTramiteId(String tramiteId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/documentos/public/tramite/$tramiteId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((d) => DocumentoModel.fromJson(d)).toList();
    }
    throw Exception('Error al obtener documentos: ${response.statusCode}');
  }

  /// Sube un archivo como documento asociado a un trámite.
  Future<DocumentoModel> upload({
    required String tramiteId,
    required File file,
    required String nombre,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/documentos/public/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['tramiteId'] = tramiteId;
    request.fields['nombre'] = nombre;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return DocumentoModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al subir documento: ${response.statusCode}');
  }

  /// Obtiene la URL de descarga de un documento.
  Future<String> getDownloadUrl(String documentoId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/documentos/$documentoId/download'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'] ?? '';
    }
    throw Exception('Error al obtener URL de descarga: ${response.statusCode}');
  }
}
