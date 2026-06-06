import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/mensaje_agente.dart';

/// Burbuja de chat para mensajes del usuario o del agente.
class ChatBubble extends StatelessWidget {
  final MensajeAgente mensaje;

  const ChatBubble({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final isUser = mensaje.esUsuario;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3F51B5) : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje.contenido,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.Hm().format(mensaje.timestamp),
              style: TextStyle(
                color: isUser ? Colors.white60 : Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
