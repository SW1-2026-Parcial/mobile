import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seguimiento_provider.dart';
import '../providers/tramite_tracker_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/tramite_status_badge.dart';
import '../widgets/tramite_timeline.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final TextEditingController _ticketController = TextEditingController();
  bool _initFromArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initFromArgs) {
      final ticketArg = ModalRoute.of(context)?.settings.arguments as String?;
      if (ticketArg != null && ticketArg.isNotEmpty) {
        _initFromArgs = true;
        _ticketController.text = ticketArg;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buscar(ticketArg);
        });
      }
    }
  }

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  void _buscar(String ticket) {
    final trimmed = ticket.trim();
    if (trimmed.isEmpty) return;
    context.read<SeguimientoProvider>().buscarTramite(trimmed).then((_) {
      _intentarAgregarAlTracker(trimmed);
    });
  }

  void _intentarAgregarAlTracker(String ticketNumber) {
    final provider = context.read<SeguimientoProvider>();
    if (provider.tramite == null) return;

    final tracker = context.read<TramiteTrackerProvider>();
    if (tracker.contiene(ticketNumber)) return;

    if (tracker.estaLleno) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite de 3 trámites alcanzado. Deja de seguir uno para agregar este.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    tracker.agregar(provider.tramite!);
  }

  void _dejarDeSeguir(String ticketNumber) {
    context.read<TramiteTrackerProvider>().remover(ticketNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dejaste de seguir este trámite')),
    );
  }

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
    return Consumer2<SeguimientoProvider, TramiteTrackerProvider>(
      builder: (context, seguimiento, tracker, _) {
        final ticketActual = seguimiento.tramite?.ticketNumber;
        final estaTrackeando = ticketActual != null && tracker.contiene(ticketActual);

        return AppShell(
          title: 'Seguimiento de Trámite',
          actions: estaTrackeando
              ? [
                  IconButton(
                    icon: const Icon(Icons.bookmark_remove),
                    tooltip: 'Dejar de seguir',
                    onPressed: () => _dejarDeSeguir(ticketActual),
                  ),
                ]
              : null,
          body: Column(
            children: [
              _buildBuscador(),
              const Divider(height: 1),
              Expanded(child: _buildContent(seguimiento)),
            ],
          ),
        );
      },
    );
  }
}
