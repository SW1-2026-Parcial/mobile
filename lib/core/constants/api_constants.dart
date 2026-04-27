class ApiConstants {
  // Configuración de Servidor (Pruebas locales)
//  static const String baseUrl = "http://localhost:8080/api";
  static const String baseUrl = "http://192.168.0.43:8080/api";
  static const String wsUrl = "ws://localhost:8080/ws/websocket"; // Protocolo WS para STOMP

  // Endpoints Públicos (ADR-006)
  static const String publicTramite = "/tramites/ticket";
  static const String publicPolicies = "/policies/public";
  
}