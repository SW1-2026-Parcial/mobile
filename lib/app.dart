// lib/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/fcm_service.dart';
import 'presentation/providers/politica_catalog_provider.dart';
import 'presentation/providers/seguimiento_provider.dart';
import 'presentation/screens/politicas_screen.dart';
import 'presentation/screens/seguimiento_screen.dart';

/// Widget raíz de la aplicación.
///
/// Configura [MultiProvider] con los providers globales y
/// [MaterialApp] con rutas nombradas.
///
/// ── PUSH NOTIFICATION ──
/// Inicializa [FcmService] en [initState] para configurar handlers
/// de notificaciones en foreground y tap desde background/terminated.
class BpmClientApp extends StatefulWidget {
  const BpmClientApp({super.key});

  @override
  State<BpmClientApp> createState() => _BpmClientAppState();
}

class _BpmClientAppState extends State<BpmClientApp> {
  // ── PUSH NOTIFICATION ── key global para navegar desde notificaciones
  // sin necesitar un BuildContext activo
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ── PUSH NOTIFICATION ── servicio FCM centralizado
  final FcmService _fcmService = FcmService();

  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  /// Inicializa los handlers de notificaciones push.
  ///
  /// ── PUSH NOTIFICATION ── llamado una sola vez al arrancar la app.
  Future<void> _initFcm() async {
    // ── PUSH NOTIFICATION ── handler para mensajes recibidos con app abierta
    _fcmService.setupForegroundHandler(
      onMessage: (message) {
        // Mostrar un SnackBar cuando llega una notif y la app está abierta
        final title = message.notification?.title ?? 'Actualización';
        final body = message.notification?.body ?? '';
        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title: $body')),
          );
        }
      },
    );

    // ── PUSH NOTIFICATION ── handler para cuando usuario toca la notif
    // (background o app terminada) → navega a /seguimiento con ticketNumber
    _fcmService.setupTapHandler(_navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PoliticaCatalogProvider()),
        // ── PUSH NOTIFICATION ── SeguimientoProvider recibe FcmService
        // para obtener el token y registrarlo en el backend
        ChangeNotifierProvider(
          create: (_) => SeguimientoProvider(_fcmService),
        ),
      ],
      child: MaterialApp(
        title: 'BPM — Consulta de Trámites',
        navigatorKey: _navigatorKey, // ← necesario para navegación desde push
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        // Rutas nombradas
        initialRoute: '/',
        routes: {
          '/': (_) => const PoliticasScreen(),
          // ── PUSH NOTIFICATION ── ruta destino al tocar notif push
          '/seguimiento': (_) => const SeguimientoScreen(),
        },
      ),
    );
  }
}
