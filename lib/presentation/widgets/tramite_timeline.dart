
import 'package:flutter/material.dart';
import '../../domain/models/tramite_event.dart';

class TramiteTimeline extends StatelessWidget {
  /// Lista de eventos a mostrar, ordenados de más antiguo a más reciente.
  final List<TramiteEvent> eventos;

  const TramiteTimeline({super.key, required this.eventos});

  /// Devuelve ícono según el tipo de evento.
  IconData _icono(String eventType) {
    switch (eventType) {
      case 'NODE_ENTERED':
        return Icons.arrow_forward_ios;
      case 'TASK_COMPLETED':
        return Icons.check_circle_outline;
      case 'TASK_REJECTED':
        return Icons.cancel_outlined;
      case 'FORK_SPLIT':
        return Icons.call_split;
      case 'JOIN_SYNCHRONIZED':
        return Icons.merge_type;
      case 'COMPLETED':
        return Icons.verified;
      case 'CANCELLED':
        return Icons.block;
      default:
        return Icons.info_outline;
    }
  }

  /// Devuelve color del ícono según el tipo de evento.
  Color _color(String eventType) {
    switch (eventType) {
      case 'TASK_COMPLETED':
      case 'JOIN_SYNCHRONIZED':
      case 'COMPLETED':
        return const Color(0xFF4CAF50); // verde
      case 'TASK_REJECTED':
      case 'CANCELLED':
        return const Color(0xFFF44336); // rojo
      case 'NODE_ENTERED':
        return const Color(0xFF2196F3); // azul
      case 'FORK_SPLIT':
        return const Color(0xFF9C27B0); // púrpura (paralelismo)
      default:
        return const Color(0xFF9E9E9E); // gris
    }
  }

  /// Devuelve descripción legible del tipo de evento.
  String _descripcion(String eventType) {
    switch (eventType) {
      case 'NODE_ENTERED':
        return 'Trámite avanzó a un nuevo paso';
      case 'TASK_COMPLETED':
        return 'Paso completado';
      case 'TASK_REJECTED':
        return 'Paso rechazado — tomando flujo alternativo';
      case 'FORK_SPLIT':
        return 'Proceso paralelo iniciado';
      case 'JOIN_SYNCHRONIZED':
        return 'Pasos paralelos sincronizados';
      case 'COMPLETED':
        return 'Trámite finalizado exitosamente';
      case 'CANCELLED':
        return 'Trámite cancelado';
      default:
        return eventType;
    }
  }

  /// Formatea timestamp ISO 8601 a formato legible (HH:mm · dd/MM).
  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$hh:$mm · $dd/$mo';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'Esperando actualizaciones...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final evento = eventos[index];
        final esUltimo = index == eventos.length - 1;
        final color = _color(evento.eventType);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda: ícono + línea conectora
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Icon(_icono(evento.eventType), color: color, size: 22),
                    if (!esUltimo)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Columna derecha: descripción + timestamp + comentario
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _descripcion(evento.eventType),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(evento.timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (evento.comentario != null &&
                          evento.comentario!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          evento.comentario!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
