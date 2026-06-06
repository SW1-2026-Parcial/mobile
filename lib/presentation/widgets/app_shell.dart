import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tramite_tracker_provider.dart';
import '../../domain/models/tramite_model.dart';

class AppShell extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAgentFab;

  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showAgentFab = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        actions: actions,
      ),
      drawer: _TramiteDrawer(),
      body: body,
      floatingActionButton: floatingActionButton ??
          (showAgentFab
              ? FloatingActionButton(
                  heroTag: 'agent_fab',
                  backgroundColor: const Color(0xFF3F51B5),
                  onPressed: () => Navigator.pushNamed(context, '/agente'),
                  child: const Icon(Icons.smart_toy, color: Colors.white),
                )
              : null),
    );
  }
}

class _TramiteDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<TramiteTrackerProvider>(
        builder: (context, tracker, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF3F51B5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text(
                      'BPM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Consulta de Trámites',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Catálogo de Políticas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/');
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 4, top: 8, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trámites seguidos (${tracker.tramites.length}/${TramiteTrackerProvider.maxTramites})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.manage_search,
                          color: Color(0xFF3F51B5)),
                      tooltip: 'Consultar trámite',
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/seguimiento');
                      },
                    ),
                  ],
                ),
              ),
              if (tracker.tramites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sin trámites seguidos',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                ...tracker.tramites.map(
                  (tramite) => _TramiteDrawerItem(
                    tramite: tramite,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/seguimiento',
                        arguments: tramite.ticketNumber,
                      );
                    },
                    onRemove: () => tracker.remover(tramite.ticketNumber),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TramiteDrawerItem extends StatelessWidget {
  final TramiteModel tramite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TramiteDrawerItem({
    required this.tramite,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_statusIcon(tramite.status), color: _statusColor(tramite.status)),
      title: Text(
        tramite.ticketNumber,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        tooltip: 'Dejar de seguir',
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }

  IconData _statusIcon(TramiteStatus status) {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return Icons.hourglass_top;
      case TramiteStatus.COMPLETED:
        return Icons.check_circle;
      case TramiteStatus.REJECTED:
        return Icons.cancel;
      case TramiteStatus.CANCELLED:
        return Icons.cancel_outlined;
    }
  }

  Color _statusColor(TramiteStatus status) {
    switch (status) {
      case TramiteStatus.ACTIVE:
        return Colors.orange;
      case TramiteStatus.COMPLETED:
        return Colors.green;
      case TramiteStatus.REJECTED:
        return Colors.red;
      case TramiteStatus.CANCELLED:
        return Colors.grey;
    }
  }
}
