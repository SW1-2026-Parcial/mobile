// lib/core/services/fcm_service.dart
//
// ══════════════════════════════════════════════════════════════════
// PUSH NOTIFICATIONS — FcmService
// ══════════════════════════════════════════════════════════════════
// Responsabilidad: centralizar toda la lógica de Firebase Cloud Messaging.
//
// TIMELINE PUSH:
//   1. requestPermission()       → solicitar permisos iOS/Android
//   2. getToken()                → obtener token para registrar en backend
//   3. setupForegroundHandler()  → mostrar notif mientras app está en foreground
//   4. setupTapHandler()         → navegar al abrir notif desde background/terminated
// ══════════════════════════════════════════════════════════════════

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Error al obtener token: $e');
      return null;
    }
  }

  void setupForegroundHandler({required void Function(RemoteMessage) onMessage}) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  // ─────────────────────────────────────────────────────────────────
  // PUSH NOTIFICATION — Navegar al tocar notificación
  // ─────────────────────────────────────────────────────────────────

  void setupTapHandler(GlobalKey<NavigatorState> navigatorKey) {
    // ── PUSH NOTIFICATION ── app abierta desde background al tocar notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navegarASeguimiento(navigatorKey, message);
    });

    // ── PUSH NOTIFICATION ── app abierta desde estado terminado (killed) al tocar notif
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _navegarASeguimiento(navigatorKey, message);
      }
    }).catchError((e) {
      debugPrint('[FCM] Error al obtener mensaje inicial: $e');
    });
  }

  /// Extrae [ticketNumber] del payload FCM y navega a la pantalla de seguimiento.
  ///
  /// El backend siempre envía `ticketNumber` en `message.data` según CONTEXTO_MOVIL.md §7.
  void _navegarASeguimiento(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    // ── PUSH NOTIFICATION ── extraer ticketNumber del payload data del backend
    final ticketNumber = message.data['ticketNumber'] as String?;
    if (ticketNumber != null && ticketNumber.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(
        '/seguimiento',
        arguments: ticketNumber,
      );
      debugPrint('[FCM] Navegando a /seguimiento con ticket: $ticketNumber');
    }
  }
}
