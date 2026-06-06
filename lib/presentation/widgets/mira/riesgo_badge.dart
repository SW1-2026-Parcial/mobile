import 'package:flutter/material.dart';

/// Badge visual que indica el nivel de riesgo MIRA de un trámite.
class RiesgoBadge extends StatelessWidget {
  final String nivel; // BAJO, MEDIO, ALTO, CRITICO
  final bool compact;

  const RiesgoBadge({
    super.key,
    required this.nivel,
    this.compact = false,
  });

  Color get _color {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return Colors.red;
      case 'ALTO':
        return Colors.deepOrange;
      case 'MEDIO':
        return Colors.orange;
      case 'BAJO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return Icons.error;
      case 'ALTO':
        return Icons.warning;
      case 'MEDIO':
        return Icons.info;
      case 'BAJO':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            nivel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
