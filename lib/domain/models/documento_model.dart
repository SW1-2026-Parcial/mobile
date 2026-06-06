/// Modelo de documento asociado a un trámite.
class DocumentoModel {
  final String id;
  final String nombre;
  final String extension;
  final int tamano;
  final String mimeType;
  final String? tramiteId;
  final String? url;
  final DateTime? creadoEn;

  DocumentoModel({
    required this.id,
    required this.nombre,
    required this.extension,
    required this.tamano,
    required this.mimeType,
    this.tramiteId,
    this.url,
    this.creadoEn,
  });

  factory DocumentoModel.fromJson(Map<String, dynamic> json) => DocumentoModel(
        id: json['id'] ?? json['_id'] ?? '',
        nombre: json['nombre'] ?? '',
        extension: json['extension'] ?? '',
        tamano: json['tamano'] ?? 0,
        mimeType: json['mimeType'] ?? '',
        tramiteId: json['tramiteId'],
        url: json['url'],
        creadoEn: json['creadoEn'] != null
            ? DateTime.tryParse(json['creadoEn'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'extension': extension,
        'tamano': tamano,
        'mimeType': mimeType,
        'tramiteId': tramiteId,
        'url': url,
        'creadoEn': creadoEn?.toIso8601String(),
      };

  String get sizeFormatted {
    if (tamano < 1024) return '$tamano B';
    if (tamano < 1024 * 1024) return '${(tamano / 1024).toStringAsFixed(1)} KB';
    return '${(tamano / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
