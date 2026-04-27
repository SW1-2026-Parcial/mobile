enum TramiteStatus { ACTIVE, COMPLETED, REJECTED, PAUSED }

class TramiteModel {
  final String id;
  final String ticketNumber;
  final TramiteStatus status;
  final List<String> currentNodeIds; // Soporte para FORK/paralelismo [cite: 15, 79]
  final String? startedAt;
  final String? completedAt;

  TramiteModel({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.currentNodeIds,
    this.startedAt,
    this.completedAt,
  });

  factory TramiteModel.fromJson(Map<String, dynamic> json) {
    return TramiteModel(
      id: json['id'],
      ticketNumber: json['ticketNumber'],
      status: TramiteStatus.values.firstWhere((e) => e.name == json['status']),
      currentNodeIds: List<String>.from(json['currentNodeIds']),
      startedAt: json['startedAt'],
      completedAt: json['completedAt'],
    );
  }
}