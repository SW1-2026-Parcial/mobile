import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../constants/api_constants.dart';

class StompClientConfig {
  late StompClient client;

  void connect(String tramiteId, Function(Map<String, dynamic>) onEventReceived) {
    client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: (frame) {
          client.subscribe(
            destination: '/topic/tramites/$tramiteId',
            callback: (frame) {
              if (frame.body != null) {
                final data = jsonDecode(frame.body!);
                onEventReceived(data); // Notifica a la UI el cambio de estado
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => print("Error WS: $error"),
      ),
    );
    client.activate();
  }

  void disconnect() {
    client.deactivate(); // Importante para el ciclo de vida de la App
  }
}