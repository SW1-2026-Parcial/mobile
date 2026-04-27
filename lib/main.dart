import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app.dart';

// ── PUSH NOTIFICATION ── handler de mensajes en background/terminated
// Función top-level obligatoria — no mover dentro de ninguna clase
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el isolate del background handler
  await Firebase.initializeApp();
  debugPrint(
    '[FCM Background] evento: ${message.data['eventType']} | '
    'ticket: ${message.data['ticketNumber']}',
  );
  // No navegar aquí — la navegación ocurre en FcmService.setupTapHandler()
  // cuando el usuario toca la notificación
}

/// Punto de entrada de la aplicación Flutter.
///
/// Inicializa Firebase, registra el background handler de FCM y
/// lanza [BpmClientApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

  runApp(const BpmClientApp());
}
