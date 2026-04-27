import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );

    const initSettings = InitializationSettings(iOS: iosSettings);

    await _plugin.initialize(initSettings);

    // Solicitar permisos explícitamente en iOS 16+
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: true);

    debugPrint('[LocalNotif] Servicio inicializado');
  }

  Future<void> showTramiteUpdate({
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      const details = NotificationDetails(iOS: iosDetails);

      await _plugin.show(42, titulo, cuerpo, details);
      debugPrint('[LocalNotif] Notificación enviada: $titulo');
    } catch (e) {
      debugPrint('[LocalNotif] Error al mostrar notificación: $e');
    }
  }
}
