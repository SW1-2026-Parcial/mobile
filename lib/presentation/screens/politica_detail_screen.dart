import 'package:flutter/material.dart';
import '../../domain/models/politica_model.dart';
import '../widgets/app_shell.dart';

class PoliticaDetailScreen extends StatelessWidget {
  final PoliticaModel politica;

  const PoliticaDetailScreen({super.key, required this.politica});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Detalle de Política',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: Color(0xFF3F51B5), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    politica.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Descripción',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              politica.descripcion,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ID: ${politica.id}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
