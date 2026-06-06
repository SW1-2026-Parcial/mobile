# SP1-MOBILE — CLAUDE.md

## Qué es este proyecto

App móvil Flutter del sistema BPM (Business Policy Manager). Permite a usuarios finales (clientes/ciudadanos) consultar el estado de su trámite con un número de ticket, interactuar con un agente inteligente para iniciar trámites, y subir/ver documentos asociados.

**Stack:** Flutter (Dart 3.11) · Provider 6.1 · HTTP · STOMP Dart · SQLite/Hive (Ciclo 2)

---

## Arquitectura actual (Ciclo 1 — completado)

```
lib/
├── core/
│   ├── constants/          → URLs base, colores, strings
│   ├── network/            → HttpClient configurado con base URL
│   └── services/           → Servicios base (storage, etc.)
├── data/
│   ├── providers/          → Data providers (API calls)
│   └── repositories/       → Repositorios (capa de abstracción sobre providers)
├── domain/
│   ├── models/             → Modelos Dart (Tramite, Politica, etc.)
│   └── service/            → Lógica de negocio
└── presentation/
    ├── providers/          → Provider state management
    ├── screens/
    │   ├── politicas_screen.dart       → Lista de políticas publicadas
    │   ├── politica_detail_screen.dart  → Detalle de política
    │   └── seguimiento_screen.dart      → Seguimiento por ticket (CU-12)
    └── widgets/            → Widgets reutilizables
```

### Dependencias actuales (pubspec.yaml)

| Paquete | Uso |
|---|---|
| `provider` | State management |
| `http` | Llamadas HTTP al backend |
| `stomp_dart_client` | WebSocket STOMP para updates en tiempo real |
| `flutter_local_notifications` | Notificaciones locales |

### Conexión con backend

- **API Base:** Backend Spring Boot (configurable, default `http://10.0.2.2:8080/api/` para emulador)
- **Endpoints públicos** (sin JWT): `/api/tramites/ticket/{n}`, `/api/policies/public`, FCM token
- **WebSocket:** STOMP a `/ws-native` (WebSocket puro, sin SockJS)
- **Push:** Firebase Cloud Messaging (FCM) para notificaciones cuando hay cambios en el trámite

---

## Ciclo 2 — Funcionalidades a implementar

### PRIORIDAD 1: Offline 100% (REQUISITO CRÍTICO)

**Objetivo:** La app DEBE funcionar completamente sin internet. Sincroniza cuando recupera conexión.

**Base de datos local — Hive o sqflite:**

```
lib/core/database/
├── local_database.dart         → Inicialización de Hive/SQLite
├── boxes/                      → (si Hive) Box por entidad
│   ├── tramites_box.dart
│   ├── politicas_box.dart
│   ├── documentos_box.dart
│   ├── conversaciones_box.dart
│   └── pending_actions_box.dart
└── sync/
    ├── sync_service.dart       → Push/pull contra /api/sync/*
    ├── sync_queue.dart         → Cola FIFO de acciones pendientes
    └── conflict_resolver.dart  → Resolución de conflictos (last-write-wins o manual)
```

**Dependencias a agregar en pubspec.yaml:**

```yaml
dependencies:
  hive: ^2.2.3                    # BD local NoSQL (o usar sqflite si prefieres SQL)
  hive_flutter: ^1.1.0
  connectivity_plus: ^6.0.0       # Detectar estado de red
  workmanager: ^0.5.2             # Background sync en Android/iOS
  path_provider: ^2.1.0           # Rutas de filesystem

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.0
```

**Estrategia de sincronización:**

1. **Al iniciar la app:** verificar conexión → si hay, `POST /api/sync/pull` con último timestamp
2. **Acciones offline:** toda acción (completar tarea, subir documento, chat con agente) se guarda en `pending_actions` con timestamp
3. **Al recuperar conexión:** 
   - `POST /api/sync/push` con acciones pendientes
   - `POST /api/sync/pull` para recibir cambios del servidor
   - Limpiar cola de pendientes
4. **Background sync:** usar `workmanager` para sincronizar periódicamente en background

**Widget indicador de estado:**

```dart
// Widget que muestra el estado de conexión en toda la app
class ConnectivityBanner extends StatelessWidget {
  // Escucha connectivity_plus
  // Muestra banner rojo "Sin conexión" o verde "Sincronizando..."
}
```

**Cache de documentos:**
- Descargar PDFs/imágenes críticos para consulta offline
- Guardar en `getApplicationDocumentsDirectory()` con path relativo al s3Key
- Limitar caché a 500MB, LRU eviction

---

### PRIORIDAD 2: Agente Inteligente (Feature principal móvil)

**Objetivo:** Chatbot con voz y texto que identifica qué política necesita el usuario, recopila datos obligatorios, e inicia el trámite.

**Nueva estructura:**

```
lib/presentation/screens/agent/
├── agent_chat_screen.dart          → Pantalla principal del agente
├── agent_voice_screen.dart         → Pantalla de grabación de voz (o integrado como botón)
└── agent_confirm_screen.dart       → Resumen de datos antes de iniciar trámite

lib/presentation/widgets/agent/
├── chat_bubble.dart                → Burbuja de mensaje (usuario vs agente)
├── voice_record_button.dart        → Botón animado de grabación
├── datos_recopilados_card.dart     → Card con los datos que el agente ya tiene
└── typing_indicator.dart           → Indicador "el agente está escribiendo..."

lib/data/repositories/
├── agent_repository.dart           → Llamadas a /api/agent/*

lib/domain/models/
├── conversacion.dart               → Modelo de conversación con historial
├── mensaje_agente.dart             → Modelo de mensaje individual
```

**Dependencias a agregar:**

```yaml
dependencies:
  record: ^5.1.0                    # Grabación de audio
  audioplayers: ^6.1.0              # Reproducción de respuesta de voz
  permission_handler: ^11.3.0       # Permisos de micrófono
  speech_to_text: ^7.0.0            # Alternativa: STT local antes de enviar
```

**Flujo del agente:**

1. **Pantalla de chat:** lista de burbujas (usuario ← → agente), campo de texto + botón de voz
2. **Texto:** usuario escribe → `POST /api/agent/chat` con `{sessionId, mensaje}` → respuesta del agente
3. **Voz:** usuario presiona botón → graba audio → `POST /api/agent/voice` con multipart → respuesta texto + audio
4. **Recopilación:** el agente muestra card con datos ya recopilados y qué falta
5. **Confirmación:** cuando todos los datos obligatorios están → pantalla de resumen → botón "Iniciar trámite"
6. **Offline:** los mensajes se encolan y se envían al reconectar (conversación parcial guardada en Hive)

**Integración en la navegación:**
- Botón flotante (FAB) o tab dedicado "Agente" en la pantalla principal
- Badge con conversaciones activas

---

### PRIORIDAD 3: Gestión Documental (vista cliente)

**Objetivo:** El cliente puede ver documentos de su trámite, subir los que le pidan, y previsualizar PDFs/imágenes.

**Nueva estructura:**

```
lib/presentation/screens/documentos/
├── documentos_list_screen.dart     → Lista de documentos del trámite
├── documento_detail_screen.dart    → Detalle + previsualización
└── upload_documento_screen.dart    → Subir foto/PDF desde cámara o galería

lib/presentation/widgets/documentos/
├── documento_tile.dart             → ListTile con icono, nombre, fecha, estado
├── formato_icon.dart               → Icono dinámico por extensión
└── upload_progress.dart            → Barra de progreso de subida

lib/data/repositories/
├── documento_repository.dart       → Llamadas a /api/documentos/*
```

**Dependencias a agregar:**

```yaml
dependencies:
  image_picker: ^1.1.0             # Seleccionar foto/archivo de galería o cámara
  file_picker: ^8.0.0              # Seleccionar archivos genéricos
  flutter_pdfview: ^1.3.2          # Visor de PDF embebido
  open_filex: ^4.5.0               # Abrir Word/Excel con app externa del dispositivo
  dio: ^5.7.0                      # HTTP con soporte de upload multipart + progreso
```

**Funcionalidades:**
- **Lista:** filtrada por `ticketNumber` del cliente, muestra estado (aprobado/pendiente/rechazado)
- **Subir:** cámara directa o galería, con compresión de imagen antes de subir
- **Previsualizar:** PDF inline con `flutter_pdfview`, imágenes con `Image.network` + cache, Word/Excel con `open_filex`
- **Offline:** documentos descargados se guardan en cache local para consulta sin red

---

### PRIORIDAD 4: Notificaciones MIRA mejoradas

**Objetivo:** El cliente recibe push notifications cuando MIRA detecta algo relevante para su trámite.

**Cambios:**
- Ampliar el handler de FCM para interpretar nuevos tipos: `MIRA_RIESGO_DEMORA`, `MIRA_ANOMALIA`
- En `seguimiento_screen.dart` (pantalla de tracking del trámite):
  - Agregar sección "Estimación MIRA" con tiempo estimado restante
  - Badge de riesgo (verde/amarillo/rojo) junto al estado del trámite

**Nueva estructura:**

```
lib/presentation/widgets/mira/
├── riesgo_badge.dart               → Badge de color según nivel de riesgo
├── estimacion_tiempo.dart          → Widget con tiempo estimado restante
└── mira_alert_card.dart            → Card de alerta MIRA en la pantalla de seguimiento
```

---

### PRIORIDAD 5: Reportes (para Supervisor/Admin en móvil)

**Objetivo:** Si un supervisor/admin usa la app móvil, puede solicitar reportes por voz/texto.

**Nueva estructura:**

```
lib/presentation/screens/reportes/
├── solicitar_reporte_screen.dart   → TextField/voz para prompt + selector de formato
└── reportes_list_screen.dart       → Lista de reportes generados con estado

lib/data/repositories/
├── reporte_repository.dart         → Llamadas a /api/reportes/*
```

**Notas:**
- Solo visible si el usuario tiene rol SUPERVISOR o ADMINISTRADOR
- Notificación push cuando el reporte está listo para descargar
- Descarga del archivo via URL presignada de S3 → abrir con app externa del dispositivo

---

## Convenciones de código

- **Arquitectura:** Clean Architecture con 4 capas: `core/`, `data/`, `domain/`, `presentation/`
- **State management:** Provider (ya configurado, NO migrar a Riverpod/Bloc)
- **Naming:** Archivos en snake_case, clases en PascalCase, constantes en UPPER_SNAKE_CASE
- **Widgets:** Extraer widgets reutilizables a `widgets/`, pantallas completas a `screens/`
- **Modelos:** Clases inmutables con `factory fromJson()` y `Map<String, dynamic> toJson()`
- **HTTP:** Usar `http` package para requests simples, `dio` para uploads con progreso
- **Offline first:** TODA operación debe funcionar sin red — guardar en local primero, sincronizar después
- **Permisos:** Pedir permisos con `permission_handler` antes de usar cámara/micrófono
- **Navegación:** Navigator 2.0 o GoRouter si se migra

---

## Cómo correr

```bash
flutter pub get
flutter run                           # Emulador o dispositivo conectado
flutter build apk --release           # APK de producción
flutter build ios --release           # iOS de producción

# Generar código Hive (Ciclo 2):
dart run build_runner build
```
