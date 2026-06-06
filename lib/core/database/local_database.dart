import 'package:hive_flutter/hive_flutter.dart';

/// Inicializa Hive y abre los boxes necesarios para offline-first.
class LocalDatabase {
  static const String tramitesBox = 'tramites';
  static const String politicasBox = 'politicas';
  static const String conversacionesBox = 'conversaciones';
  static const String pendingActionsBox = 'pending_actions';
  static const String documentosBox = 'documentos';
  static const String configBox = 'config';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox(tramitesBox),
      Hive.openBox(politicasBox),
      Hive.openBox(conversacionesBox),
      Hive.openBox(pendingActionsBox),
      Hive.openBox(documentosBox),
      Hive.openBox(configBox),
    ]);
  }

  static Box get tramites => Hive.box(tramitesBox);
  static Box get politicas => Hive.box(politicasBox);
  static Box get conversaciones => Hive.box(conversacionesBox);
  static Box get pendingActions => Hive.box(pendingActionsBox);
  static Box get documentos => Hive.box(documentosBox);
  static Box get config => Hive.box(configBox);

  /// Obtiene el último timestamp de sincronización.
  static DateTime? get lastSync {
    final ms = config.get('lastSyncMs');
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Guarda el timestamp de la última sincronización.
  static set lastSync(DateTime? value) {
    if (value != null) {
      config.put('lastSyncMs', value.millisecondsSinceEpoch);
    }
  }
}
