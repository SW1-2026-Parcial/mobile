class TramiteEvent {
  final String tramiteId;
  final String eventType; // NODE_ENTERED, TASK_COMPLETED, etc. [cite: 145]
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
      tramiteId: json['tramiteId'],
      eventType: json['eventType'],
      nodeId: json['nodeId'],
      comentario: json['comentario'],
      timestamp: json['timestamp'],
    );
  }
}