import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/sync/connectivity_service.dart';
import 'core/database/sync/sync_service.dart';
import 'core/services/local_notification_service.dart';
import 'presentation/providers/agent_provider.dart';
import 'presentation/providers/politica_catalog_provider.dart';
import 'presentation/providers/seguimiento_provider.dart';
import 'presentation/providers/tramite_tracker_provider.dart';
import 'presentation/screens/agent/agent_chat_screen.dart';
import 'presentation/screens/politicas_screen.dart';
import 'presentation/screens/seguimiento_screen.dart';
import 'presentation/widgets/connectivity_banner.dart';

class BpmClientApp extends StatefulWidget {
  const BpmClientApp({super.key});

  @override
  State<BpmClientApp> createState() => _BpmClientAppState();
}

class _BpmClientAppState extends State<BpmClientApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final LocalNotificationService _localNotifService = LocalNotificationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _localNotifService.initialize();
    _syncService = SyncService(_connectivityService);

    if (_connectivityService.isOnline) {
      _syncService.syncAll();
    }
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalNotificationService>.value(value: _localNotifService),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: _connectivityService,
        ),
        ChangeNotifierProvider(create: (_) => PoliticaCatalogProvider()),
        ChangeNotifierProvider(create: (_) => SeguimientoProvider()),
        ChangeNotifierProvider(
          create: (_) => TramiteTrackerProvider(_localNotifService),
        ),
        ChangeNotifierProvider(
          create: (_) => AgentProvider(_connectivityService),
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
          '/': (_) => const _AppWithBanner(child: PoliticasScreen()),
          '/seguimiento': (_) => const _AppWithBanner(child: SeguimientoScreen()),
          '/agente': (_) => const _AppWithBanner(child: AgentChatScreen()),
        },
      ),
    );
  }
}

/// Wrapper que agrega el banner de conectividad sobre cualquier pantalla.
class _AppWithBanner extends StatelessWidget {
  final Widget child;

  const _AppWithBanner({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ConnectivityBanner(),
        Expanded(child: child),
      ],
    );
  }
}
