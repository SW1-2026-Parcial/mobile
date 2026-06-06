class ApiConstants {
  // ── Entorno activo ────────────────────────────────────────────────────────────
  // Cambiar según donde se corre:
  //   macOS/iOS Simulator → localhost
  //   Android Emulator    → 10.0.2.2
  //   Dispositivo físico  → IP local (ej: 192.168.1.x)
  //   Producción          → URL de Azure (descomentar línea prod)

  static const String baseUrl = "http://localhost:8080/api";
  static const String wsUrl   = "ws://localhost:8080/ws";

  // static const String baseUrl = "http://10.0.2.2:8080/api";           // Android Emulator
  // static const String wsUrl   = "ws://10.0.2.2:8080/ws/websocket";
  // static const String baseUrl = "https://backend-prod.proudsmoke-dbce02fc.eastus2.azurecontainerapps.io/api";  // Producción
  // static const String wsUrl   = "wss://backend-prod.proudsmoke-dbce02fc.eastus2.azurecontainerapps.io/ws/websocket";

  // Endpoints Públicos (ADR-006)
  static const String publicTramite = "/tramites/ticket";
  static const String publicPolicies = "/policies/public";

  // Agente
  static const String agentChat = "/agent/chat";
  static const String agentClear = "/agent/clear-session";

  // Documentos
  static const String documentos = "/documentos";
}
