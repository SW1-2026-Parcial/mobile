import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Botón de micrófono con animación pulsante durante grabación.
/// Convierte voz a texto y lo entrega via [onResult].
class VoiceRecordButton extends StatefulWidget {
  final void Function(String texto) onResult;
  final bool enabled;

  const VoiceRecordButton({
    super.key,
    required this.onResult,
    this.enabled = true,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _partial = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _pulseCtrl.reverse();
        if (s == AnimationStatus.dismissed && _listening) _pulseCtrl.forward();
      });
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initStt();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onError: (_) => _stopListening(),
    );
    if (mounted) setState(() => _available = ok);
  }

  Future<void> _startListening() async {
    if (!_available) {
      _showSnack('Reconocimiento de voz no disponible en este dispositivo');
      return;
    }
    setState(() {
      _listening = true;
      _partial = '';
    });
    _pulseCtrl.forward();

    await _stt.listen(
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        setState(() => _partial = result.recognizedWords);
        if (result.finalResult) {
          _stopListening();
          if (_partial.trim().isNotEmpty) {
            widget.onResult(_partial.trim());
          }
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    if (mounted) setState(() => _listening = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _listening ? _stopListening : _startListening,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: _listening ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: CircleAvatar(
          backgroundColor:
              _listening ? Colors.red : const Color(0xFF3F51B5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_listening)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
              Icon(
                _listening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
