class TramiteEvent {
  final String tramiteId;
  final String eventType;
  final String? nodeId;
  final String? comentario;
  final String timestamp;

  TramiteEvent({
    required this.tramiteId,
    required this.eventType,
    this.nodeId,
    this.comentario,
    required this.timestamp,
  });

  factory TramiteEvent.fromJson(Map<String, dynamic> json) {
    return TramiteEvent(
      tramiteId: json['tramiteId'] ?? '',
      eventType: json['eventType'] ?? json['tipo'] ?? json['type'] ?? '',
      nodeId: json['nodeId'],
      comentario: json['comentario'],
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}
