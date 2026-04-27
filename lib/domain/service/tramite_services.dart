import '../models/tramite_model.dart';
import '../models/tramite_event.dart';

class TramiteService {
  String obtenerColorNodo(String nodeId, TramiteModel tramite, List<TramiteEvent> historial) {
    if (tramite.currentNodeIds.contains(nodeId)) {
      return "AMARILLO"; // Nodo actualmente activo [cite: 36, 61]
    }
    
    bool isCompleted = historial.any((e) => e.nodeId == nodeId && e.eventType == "TASK_COMPLETED");
    return isCompleted ? "VERDE" : "ROJO";
  }

  void ordenarEventosPorFecha(List<TramiteEvent> eventos) {
    eventos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}