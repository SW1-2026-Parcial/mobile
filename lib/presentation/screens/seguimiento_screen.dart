import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seguimiento_provider.dart';
import '../widgets/tramite_status_badge.dart';
import '../widgets/tramite_timeline.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final TextEditingController _ticketController = TextEditingController();
  bool _initFromNotification = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initFromNotification) {
      // ── PUSH NOTIFICATION ── si la pantalla se abrió desde una notificación push,
      // el ticketNumber viene como argument de la ruta
      final ticketFromNotif =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (ticketFromNotif != null && ticketFromNotif.isNotEmpty) {
        _initFromNotification = true;
        _ticketController.text = ticketFromNotif;
        // Buscar automáticamente al abrir desde notificación
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buscar(ticketFromNotif);
        });
      }
    }
  }

  @override
  void dispose() {
    _ticketController.dispose();
    // El provider se encarga de desconectar el WebSocket en su propio dispose
    super.dispose();
  }


  void _buscar(String ticket) {
    final trimmed = ticket.trim();
    if (trimmed.isEmpty) return;
    context.read<SeguimientoProvider>().buscarTramite(trimmed);
  }

  /// Construye el campo de búsqueda de ticket.
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Número de Ticket',
                hintText: 'Ej: TRM-2026-0042',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _buscar,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _buscar(_ticketController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  /// Construye el contenido según el estado del [SeguimientoProvider].
  Widget _buildContent(SeguimientoProvider provider) {
    switch (provider.estado) {
      case SeguimientoEstado.inicial:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Ingresa tu número de ticket\npara ver el estado de tu trámite',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        );

      case SeguimientoEstado.cargando:
        return const Center(child: CircularProgressIndicator());

      case SeguimientoEstado.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );

      case SeguimientoEstado.activo:
      case SeguimientoEstado.completado:
        final tramite = provider.tramite!;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de estado del trámite
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tramite.ticketNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TramiteStatusBadge(status: tramite.status),
                        ],
                      ),
                      if (tramite.startedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Iniciado: ${tramite.startedAt}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (tramite.completedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Finalizado: ${tramite.completedAt}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Línea de tiempo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // ── PUSH NOTIFICATION ── Los eventos aquí son los mismos que
              // disparan las push notifications desde el backend.
              // El WebSocket los recibe en tiempo real; las push llegan
              // cuando la app está en background.
              TramiteTimeline(eventos: provider.eventos),
              if (provider.eventos.isEmpty &&
                  provider.estado == SeguimientoEstado.activo)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Conectado. Esperando eventos en tiempo real...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Trámite'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildBuscador(),
          const Divider(height: 1),
          Expanded(
            child: Consumer<SeguimientoProvider>(
              builder: (context, provider, _) => _buildContent(provider),
            ),
          ),
        ],
      ),
    );
  }
}
