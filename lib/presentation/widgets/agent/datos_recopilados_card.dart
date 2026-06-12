import 'package:flutter/material.dart';

/// Card que muestra los datos recopilados por el agente y qué falta.
class DatosRecopiladosCard extends StatelessWidget {
  final Map<String, dynamic> campos;
  final List<String> faltantes;
  final bool listoParaIniciar;
  final bool tramiteYaCreado;
  final String? ticketCreado;
  final VoidCallback? onIniciar;
  final VoidCallback? onVerDocumentos;

  const DatosRecopiladosCard({
    super.key,
    required this.campos,
    required this.faltantes,
    this.listoParaIniciar = false,
    this.tramiteYaCreado = false,
    this.ticketCreado,
    this.onIniciar,
    this.onVerDocumentos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: listoParaIniciar
            ? Colors.green.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: listoParaIniciar
              ? Colors.green.shade200
              : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                listoParaIniciar ? Icons.check_circle : Icons.assignment,
                size: 18,
                color: listoParaIniciar ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                listoParaIniciar
                    ? 'Datos completos'
                    : 'Datos recopilados',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: listoParaIniciar
                      ? Colors.green.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Campos completados
          ...campos.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),

          // Campos faltantes
          if (faltantes.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Text(
              'Falta: ${faltantes.join(", ")}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Trámite ya creado
          if (tramiteYaCreado && ticketCreado != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.confirmation_number,
                    size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ticket: $ticketCreado',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
                if (onVerDocumentos != null)
                  TextButton.icon(
                    onPressed: onVerDocumentos,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Ver docs'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3F51B5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],

          // Botón iniciar (solo cuando listo y no creado aún)
          if (listoParaIniciar && !tramiteYaCreado && onIniciar != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onIniciar,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('Iniciar trámite'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
