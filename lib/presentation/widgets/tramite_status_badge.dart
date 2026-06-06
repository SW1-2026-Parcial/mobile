
import 'package:flutter/material.dart';
import '../../domain/models/tramite_model.dart';

/// Colores del sistema BPM:
/// - ACTIVE    → amarillo (en proceso)
/// - COMPLETED → verde    (finalizado con éxito)
/// - REJECTED  → rojo     (rechazado)
/// - CANCELLED → gris     (cancelado)
class TramiteStatusBadge extends StatelessWidget {
  /// Estado del trámite a mostrar.
  final TramiteStatus status;

  const TramiteStatusBadge({super.key, required this.status});

  /// Devuelve el color del badge según el estado.
  Color _color() {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return const Color(0xFFFFC107); // amarillo — en proceso
      case TramiteStatus.COMPLETED:
        return const Color(0xFF4CAF50); // verde — completado
      case TramiteStatus.REJECTED:
        return const Color(0xFFF44336); // rojo — rechazado
      case TramiteStatus.CANCELLED:
        return const Color(0xFF9E9E9E); // gris — cancelado
    }
  }

  /// Devuelve el texto del badge según el estado.
  String _label() {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return 'En proceso';
      case TramiteStatus.COMPLETED:
        return 'Completado';
      case TramiteStatus.REJECTED:
        return 'Rechazado';
      case TramiteStatus.CANCELLED:
        return 'Cancelado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color(), width: 1.2),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
