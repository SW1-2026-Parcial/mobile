import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agent_provider.dart';
import '../../widgets/agent/chat_bubble.dart';
import '../../widgets/agent/datos_recopilados_card.dart';
import '../../widgets/agent/typing_indicator.dart';

/// Pantalla principal del agente conversacional.
class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviarMensaje() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    _controller.clear();
    context.read<AgentProvider>().enviarMensaje(texto);

    // Scroll al final después de agregar
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agente BPM'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Nueva conversación',
            onPressed: () => context.read<AgentProvider>().nuevaConversacion(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Datos recopilados (si hay)
          Consumer<AgentProvider>(
            builder: (_, provider, __) {
              final campos = provider.camposRecopilados;
              final faltantes = provider.camposFaltantes;
              if (campos == null || campos.isEmpty) return const SizedBox.shrink();
              return DatosRecopiladosCard(
                campos: campos,
                faltantes: faltantes ?? [],
                listoParaIniciar: provider.listoParaIniciar,
              );
            },
          ),

          // Lista de mensajes
          Expanded(
            child: Consumer<AgentProvider>(
              builder: (_, provider, __) {
                final mensajes = provider.mensajes;

                if (mensajes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            '¡Hola! Soy el asistente BPM.\nDime qué trámite necesitas realizar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: mensajes.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == mensajes.length) {
                      return const TypingIndicator();
                    }
                    return ChatBubble(mensaje: mensajes[index]);
                  },
                );
              },
            ),
          ),

          // Input de texto
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviarMensaje(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3F51B5),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _enviarMensaje,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
