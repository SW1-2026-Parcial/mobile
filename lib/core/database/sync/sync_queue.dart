import 'dart:convert';
import '../local_database.dart';

/// Representa una acción pendiente de sincronización.
class PendingAction {
  final String id;
  final String method; // POST, PUT, DELETE
  final String endpoint;
  final Map<String, dynamic>? body;
  final DateTime createdAt;

  PendingAction({
    required this.id,
    required this.method,
    required this.endpoint,
    this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        id: json['id'],
        method: json['method'],
        endpoint: json['endpoint'],
        body: json['body'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

/// Cola FIFO de acciones pendientes almacenadas en Hive.
class SyncQueue {
  /// Agrega una acción a la cola de pendientes.
  static Future<void> enqueue(PendingAction action) async {
    await LocalDatabase.pendingActions.put(action.id, jsonEncode(action.toJson()));
  }

  /// Obtiene todas las acciones pendientes en orden FIFO.
  static List<PendingAction> getAll() {
    final box = LocalDatabase.pendingActions;
    final actions = <PendingAction>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        actions.add(PendingAction.fromJson(jsonDecode(raw)));
      }
    }

    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  }

  /// Elimina una acción completada de la cola.
  static Future<void> remove(String id) async {
    await LocalDatabase.pendingActions.delete(id);
  }

  /// Retorna la cantidad de acciones pendientes.
  static int get count => LocalDatabase.pendingActions.length;

  /// Limpia toda la cola.
  static Future<void> clear() async {
    await LocalDatabase.pendingActions.clear();
  }
}
