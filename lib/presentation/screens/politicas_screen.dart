import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/politica_catalog_provider.dart';
import '../widgets/politica_card.dart';

/// Pantalla que muestra el catálogo de políticas de negocio publicadas.
///
/// Llama a `GET /api/policies/public` al inicializarse.
/// Muestra lista scrollable de [PoliticaCard].
///
/// Ruta nombrada: `/`
class PoliticasScreen extends StatefulWidget {
  const PoliticasScreen({super.key});

  @override
  State<PoliticasScreen> createState() => _PoliticasScreenState();
}

class _PoliticasScreenState extends State<PoliticasScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar políticas al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PoliticaCatalogProvider>().cargarPoliticas();
    });
  }

  /// Construye el cuerpo de la pantalla según el estado del provider.
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

    if (provider.politicas.isEmpty) {
      return const Center(
        child: Text(
          'No hay políticas disponibles por el momento.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.cargarPoliticas,
      child: ListView.builder(
        itemCount: provider.politicas.length,
        itemBuilder: (context, index) {
          return PoliticaCard(politica: provider.politicas[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Trámites'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      body: Consumer<PoliticaCatalogProvider>(
        builder: (context, provider, _) => _buildBody(provider),
      ),
    );
  }
}
