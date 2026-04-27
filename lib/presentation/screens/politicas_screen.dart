import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/local_notification_service.dart';
import '../../domain/models/politica_model.dart';
import '../providers/politica_catalog_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/politica_card.dart';
import 'politica_detail_screen.dart';

class PoliticasScreen extends StatefulWidget {
  const PoliticasScreen({super.key});

  @override
  State<PoliticasScreen> createState() => _PoliticasScreenState();
}

class _PoliticasScreenState extends State<PoliticasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticaCatalogProvider>().cargarPoliticas();
    });
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PoliticaModel> _filtrar(List<PoliticaModel> todas) {
    if (_query.isEmpty) return todas;
    return todas
        .where((p) =>
            p.nombre.toLowerCase().contains(_query) ||
            p.descripcion.toLowerCase().contains(_query))
        .toList();
  }

  void _abrirDetalle(PoliticaModel politica) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PoliticaDetailScreen(politica: politica),
      ),
    );
  }

  Widget _buildBody(PoliticaCatalogProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.cargarPoliticas,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final lista = _filtrar(provider.politicas);

    if (lista.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No hay políticas disponibles por el momento.'
              : 'Sin resultados para "$_query".',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.cargarPoliticas,
      child: ListView.builder(
        itemCount: lista.length,
        itemBuilder: (context, index) => PoliticaCard(
          politica: lista[index],
          onTap: () => _abrirDetalle(lista[index]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Catálogo de Trámites',
      actions: [
        IconButton(
          icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
          tooltip: _searchVisible ? 'Cerrar búsqueda' : 'Buscar política',
          onPressed: () {
            setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) {
                _searchController.clear();
              }
            });
          },
        ),
        // ── TEST ONLY START ──
        IconButton(
          icon: const Icon(Icons.notifications_active),
          tooltip: 'Test push',
          onPressed: () =>
              context.read<LocalNotificationService>().showTramiteUpdate(
                    titulo: '🔔 Prueba',
                    cuerpo: 'Notificación local funcionando correctamente',
                  ),
        ),
        // ── TEST ONLY END ──
      ],
      body: Column(
        children: [
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar política...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear,
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: Consumer<PoliticaCatalogProvider>(
              builder: (context, provider, _) => _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }
}
