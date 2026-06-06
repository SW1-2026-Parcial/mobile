import 'package:flutter/material.dart';

/// Widget que muestra el tiempo estimado restante según MIRA.
class EstimacionTiempo extends StatelessWidget {
  final double horasEstimadas;

  const EstimacionTiempo({super.key, required this.horasEstimadas});

  String get _textoEstimacion {
    if (horasEstimadas < 1) {
      return '< 1 hora';
    } else if (horasEstimadas < 24) {
      return '${horasEstimadas.toStringAsFixed(0)}h';
    } else {
      final dias = (horasEstimadas / 24).ceil();
      return '$dias día${dias > 1 ? "s" : ""}';
    }
  }

  Color get _color {
    if (horasEstimadas > 72) return Colors.red;
    if (horasEstimadas > 24) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: _color),
          const SizedBox(width: 6),
          Text(
            'Estimado: $_textoEstimacion',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
