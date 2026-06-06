import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    final initSettings = InitializationSettings(
      iOS: darwinSettings,
      macOS: darwinSettings,   // ← fix: macOS también necesita DarwinInitializationSettings
      android: androidSettings,
    );

    await _plugin.initialize(initSettings);

    // Solicitar permisos en iOS/macOS 16+
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);
    } else if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);
    }

    debugPrint('[LocalNotif] Servicio inicializado (${Platform.operatingSystem})');
  }

  Future<void> showTramiteUpdate({
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      const androidDetails = AndroidNotificationDetails(
        'tramites_channel',
        'Actualizaciones de Trámites',
        channelDescription: 'Notificaciones cuando cambia el estado de un trámite',
        importance: Importance.high,
        priority: Priority.high,
      );

      final details = NotificationDetails(
        iOS: darwinDetails,
        macOS: darwinDetails,
        android: androidDetails,
      );

      await _plugin.show(42, titulo, cuerpo, details);
      debugPrint('[LocalNotif] Notificación enviada: $titulo');
    } catch (e) {
      debugPrint('[LocalNotif] Error al mostrar notificación: $e');
    }
  }
}
