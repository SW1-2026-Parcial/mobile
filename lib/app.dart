import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/local_notification_service.dart';
import 'presentation/providers/politica_catalog_provider.dart';
import 'presentation/providers/seguimiento_provider.dart';
import 'presentation/screens/politicas_screen.dart';
import 'presentation/screens/seguimiento_screen.dart';

/// Widget raíz de la aplicación.
///
/// Configura [MultiProvider] con los providers globales y
/// [MaterialApp] con rutas nombradas.
class BpmClientApp extends StatefulWidget {
  const BpmClientApp({super.key});

  @override
  State<BpmClientApp> createState() => _BpmClientAppState();
}

class _BpmClientAppState extends State<BpmClientApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final LocalNotificationService _localNotifService = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    _localNotifService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PoliticaCatalogProvider()),
        ChangeNotifierProvider(
          create: (_) => SeguimientoProvider(_localNotifService),
        ),
      ],
      child: MaterialApp(
        title: 'BPM — Consulta de Trámites',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => PoliticasScreen(localNotifService: _localNotifService),
          '/seguimiento': (_) => const SeguimientoScreen(),
        },
      ),
    );
  }
}
