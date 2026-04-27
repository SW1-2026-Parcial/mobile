
import 'package:flutter/material.dart';
import '../../domain/models/politica_model.dart';

class PoliticaCard extends StatelessWidget {

  final PoliticaModel politica;

  final VoidCallback? onTap;

  const PoliticaCard({super.key, required this.politica, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: Color(0xFF3F51B5), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      politica.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                politica.descripcion,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
