# Contrato API — App Flutter (CU-12)

**Base URL:** `http://<host>:8080`
**Auth:** Ninguna — todos los endpoints de esta guía son públicos (sin JWT).
**WebSocket:** STOMP sobre `/ws` (SockJS).

---

## 1. Flujo principal

```
1. POST /api/tramites/ticket/{ticketNumber}/fcm-token  ← registrar token + obtener tramiteId
2. GET  /api/tramites/ticket/{ticketNumber}             ← estado inicial del trámite
3. WS   /topic/tramites/{tramiteId}                    ← suscripción en tiempo real
4. GET  /api/tramites/ticket/{ticketNumber}/history    ← línea de tiempo (opcional)
5. GET  /api/policies/public                           ← listado de políticas disponibles
```

---

## 2. Registrar token FCM y obtener tramiteId

```
POST /api/tramites/ticket/{ticketNumber}/fcm-token
Content-Type: application/json

Body:
{
  "fcmToken": "string"   // token FCM obtenido de FirebaseMessaging.instance.getToken()
}

Response 200:
{
  "tramiteId": "string"  // usar para suscripción WebSocket
}

Response 404: trámite no encontrado para ese ticketNumber
```

---

## 3. Obtener estado del trámite

```
GET /api/tramites/ticket/{ticketNumber}

Response 200 — TramiteResponse:
{
  "id":                "string",          // tramiteId para WebSocket
  "politicaId":        "string",
  "versionPoliticaId": "string",
  "status":            "ACTIVE" | "COMPLETED" | "REJECTED" | "PAUSED",
  "currentNodeIds":    ["string"],        // nodoIds activos actualmente
  "prioridad":         "LOW" | "MEDIUM" | "HIGH" | "URGENT",
  "initiatedBy":       "string",          // userId del funcionario
  "ticketNumber":      "string",
  "startedAt":         "2026-04-25T10:00:00Z",
  "completedAt":       "2026-04-25T11:00:00Z" | null
}

Response 404: ticket no encontrado
```

---

## 4. WebSocket (STOMP) — actualizaciones en tiempo real

**Conectar:**
```
ws://<host>:8080/ws
```

**Suscribirse al trámite:**
```
/topic/tramites/{tramiteId}
```

**Mensaje recibido (TramiteEventContext):**
```json
{
  "tramiteId":    "string",
  "eventType":    "NODE_ENTERED" | "TASK_COMPLETED" | "TASK_REJECTED" | "COMPLETED" | "CANCELLED" | ...,
  "nodeId":       "string" | null,
  "actorId":      "string" | null,
  "comentario":   "string" | null,
  "timestamp":    "2026-04-25T10:05:00Z"
}
```

**Tipos de evento relevantes para la app:**

| eventType | Acción sugerida en UI |
|---|---|
| `NODE_ENTERED` | Actualizar estado — el trámite avanzó a un nuevo nodo |
| `TASK_COMPLETED` | Mostrar "Paso completado" |
| `TASK_REJECTED` | Mostrar "Paso rechazado, retomando flujo alternativo" |
| `FORK_SPLIT` | Mostrar "Proceso paralelo iniciado" |
| `JOIN_SYNCHRONIZED` | Mostrar "Pasos paralelos sincronizados" |
| `COMPLETED` | Mostrar pantalla de éxito — trámite finalizado |
| `CANCELLED` | Mostrar pantalla de cancelación |

---

## 5. Historial / línea de tiempo

```
GET /api/tramites/{tramiteId}/history
```

> **Nota:** Usa el `tramiteId` obtenido en el paso 1 (no el `ticketNumber`). Requiere JWT (autenticado). Para el Cliente sin JWT, construye la línea de tiempo a partir de los mensajes WebSocket.
>
> Respuesta:

```json
[
  {
    "id":             "string",
    "tramiteId":      "string",
    "tipo":           "STARTED" | "NODE_ENTERED" | "TASK_COMPLETED" | ...,
    "nodeId":         "string" | null,
    "calleId":        "string" | null,
    "departamentoId": "string" | null,
    "actorId":        "string" | null,
    "formData":       {} | null,
    "branchTaken":    true | false | null,
    "comentario":     "string" | null,
    "timestamp":      "2026-04-25T10:00:00Z"
  }
]
```

> Ordenado por `timestamp` ASC (primero el más antiguo).

---

## 6. Listado de políticas disponibles

```
GET /api/policies/public
```
> **Nota:** Endpoint pendiente de implementación backend. Cuando esté disponible:

```json
[
  {
    "id":          "string",
    "nombre":      "Licencia de construcción",
    "descripcion": "Descripción completa del proceso. Documentos requeridos: DNI, plano, etc."
  }
]
```

Solo devuelve políticas con versión publicada (estado `PUBLISHED`).

---

## 7. Notificaciones push (FCM)

El backend envía push automáticamente cuando:

| Evento | Título | Cuerpo |
|---|---|---|
| El trámite avanza a un nuevo nodo | "Tu trámite avanzó" | Nombre del nodo actual |
| El trámite se completa | "Trámite finalizado" | "Tu trámite fue completado exitosamente" |
| El trámite es rechazado | "Trámite finalizado" | "Tu trámite fue rechazado" |

**Payload FCM `data` (siempre presente):**
```json
{
  "tramiteId":   "string",
  "ticketNumber":"string",
  "eventType":   "NODE_ENTERED" | "COMPLETED" | "CANCELLED",
  "status":      "ACTIVE" | "COMPLETED" | "REJECTED"
}
```

Al recibir la notificación en background, navegar a la pantalla de estado del trámite usando `ticketNumber` del payload.

---

## 8. Enums

```
EstadoTramite:  ACTIVE | COMPLETED | REJECTED | PAUSED
Prioridad:      LOW | MEDIUM | HIGH | URGENT
TramiteEventType:
  STARTED | NODE_ENTERED | TASK_TAKEN | TASK_COMPLETED | TASK_REJECTED |
  DELEGATED | DECISION_TAKEN | FORK_SPLIT | JOIN_SYNCHRONIZED |
  MERGE_PASSED | COMPLETED | CANCELLED
```

---

## 9. Errores comunes

| HTTP | Causa |
|---|---|
| 404 | `ticketNumber` no existe |
| 400 | Body malformado (ej. `fcmToken` vacío) |
| 500 | Error interno — reintentar en 3s |

---

## 10. Configuración WebSocket (Flutter — stomp_dart_client)

```dart
final client = StompClient(
  config: StompConfig(
    url: 'ws://localhost:8080/ws/websocket',
    onConnect: (frame) {
      client.subscribe(
        destination: '/topic/tramites/$tramiteId',
        callback: (frame) {
          final event = jsonDecode(frame.body!);
          // actualizar UI con event['eventType']
        },
      );
    },
  ),
);
client.activate();
```
