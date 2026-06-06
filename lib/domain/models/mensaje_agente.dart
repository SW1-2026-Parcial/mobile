/// Modelo de un mensaje individual en la conversación con el agente.
class MensajeAgente {
  final String id;
  final String contenido;
  final bool esUsuario;
  final DateTime timestamp;
  final String? politicaIdentificada;
  final Map<String, dynamic>? camposRecopilados;
  final List<String>? camposFaltantes;
  final bool listoParaIniciar;

  MensajeAgente({
    required this.id,
    required this.contenido,
    required this.esUsuario,
    required this.timestamp,
    this.politicaIdentificada,
    this.camposRecopilados,
    this.camposFaltantes,
    this.listoParaIniciar = false,
  });

  factory MensajeAgente.fromJson(Map<String, dynamic> json) => MensajeAgente(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        contenido: json['contenido'] ?? json['mensaje'] ?? '',
        esUsuario: json['esUsuario'] ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        politicaIdentificada: json['politicaIdentificada'],
        camposRecopilados: json['camposRecopilados'],
        camposFaltantes: json['camposFaltantes'] != null
            ? List<String>.from(json['camposFaltantes'])
            : null,
        listoParaIniciar: json['listoParaIniciar'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'contenido': contenido,
        'esUsuario': esUsuario,
        'timestamp': timestamp.toIso8601String(),
        'politicaIdentificada': politicaIdentificada,
        'camposRecopilados': camposRecopilados,
        'camposFaltantes': camposFaltantes,
        'listoParaIniciar': listoParaIniciar,
      };
}
