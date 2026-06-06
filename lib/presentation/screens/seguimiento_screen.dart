import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/documento_repository.dart';
import '../../domain/models/documento_model.dart';
import '../../domain/models/tramite_model.dart';
import '../providers/seguimiento_provider.dart';
import '../providers/tramite_tracker_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/tramite_status_badge.dart';
import '../widgets/tramite_timeline.dart';
import 'documentos/documentos_screen.dart';

class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final TextEditingController _ticketController = TextEditingController();
  final DocumentoRepository _docRepo = DocumentoRepository();
  bool _initFromArgs = false;

  List<DocumentoModel> _documentos = [];
  bool _docsLoading = false;
  bool _docsExpanded = false;

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
    setState(() {
      _documentos = [];
      _docsExpanded = false;
    });
    context.read<SeguimientoProvider>().buscarTramite(trimmed).then((_) {
      _intentarAgregarAlTracker(trimmed);
      _cargarDocumentos();
    });
  }

  Future<void> _cargarDocumentos() async {
    final tramite = context.read<SeguimientoProvider>().tramite;
    if (tramite == null) return;
    setState(() => _docsLoading = true);
    try {
      _documentos = await _docRepo.getByTramiteId(tramite.id);
    } catch (_) {
      _documentos = [];
    }
    if (mounted) setState(() => _docsLoading = false);
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
              const SizedBox(height: 16),
              _buildDocumentosSection(tramite),
              const SizedBox(height: 32),
            ],
          ),
        );
    }
  }

  IconData _iconForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildDocumentosSection(TramiteModel tramite) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _docsExpanded = !_docsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: Color(0xFF3F51B5)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Documentos',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_docsLoading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F51B5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_documentos.length}',
                        style: const TextStyle(
                          color: Color(0xFF3F51B5),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _docsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_docsExpanded) ...[
            const Divider(height: 1),
            if (_documentos.isEmpty && !_docsLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay documentos asociados a este trámite',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _documentos.length,
                separatorBuilder: (context2, i) => const Divider(height: 1, indent: 56),
                itemBuilder: (_, index) {
                  final doc = _documentos[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade100,
                      child: Icon(
                        _iconForExtension(doc.extension),
                        size: 20,
                        color: const Color(0xFF3F51B5),
                      ),
                    ),
                    title: Text(
                      doc.nombre,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${doc.sizeFormatted} · ${doc.extension.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      doc.extension.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentosScreen(
                          tramiteId: tramite.id,
                          ticketNumber: tramite.ticketNumber,
                        ),
                      ),
                    ).then((_) => _cargarDocumentos());
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ver todos / Subir documento'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3F51B5),
                    side: const BorderSide(color: Color(0xFF3F51B5), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
