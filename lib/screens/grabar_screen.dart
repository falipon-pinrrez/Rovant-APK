import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/reporte.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

class Grabacion {
  Grabacion(this.path, this.segundos);
  final String path;
  final int segundos;
}

/// "Graba tu mensaje": empieza a grabar al abrir, máximo 60 s.
class GrabarScreen extends StatefulWidget {
  const GrabarScreen({super.key});
  @override
  State<GrabarScreen> createState() => _GrabarScreenState();
}

class _GrabarScreenState extends State<GrabarScreen> with SingleTickerProviderStateMixin {
  static const _maximo = 60;
  final _rec = AudioRecorder();
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  final List<double> _niveles = List.filled(40, 0.05, growable: true);
  int _seg = 0;
  bool _grabando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  Future<void> _empezar() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Rovant necesita permiso de micrófono para grabar.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: path);
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
        // a.current va de ~-60 dB (silencio) a 0 dB (máximo)
        final v = ((a.current + 50) / 50).clamp(0.05, 1.0);
        setState(() {
          _niveles.add(v);
          if (_niveles.length > 40) _niveles.removeAt(0);
        });
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seg++);
        if (_seg >= _maximo) _detener();
      });
      setState(() => _grabando = true);
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar la grabación.');
    }
  }

  Future<void> _detener() async {
    if (!_grabando) return;
    _grabando = false;
    _timer?.cancel();
    await _ampSub?.cancel();
    final path = await _rec.stop();
    if (!mounted) return;
    if (path == null || _seg < 1) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, Grabacion(path, _seg));
  }

  Future<void> _cancelar() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    if (_grabando) await _rec.cancel();
    _grabando = false;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _pulso.dispose();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelar();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _cancelar),
          title: const Text('Graba tu mensaje'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 8),
              Text(
                'Puedes decir qué está pasando, la ubicación o cualquier detalle importante.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.texto2, fontSize: 15, height: 1.4),
              ),
              const Spacer(),
              if (_error != null)
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))
              else
                AnimatedBuilder(
                  animation: _pulso,
                  builder: (_, __) {
                    final t = _grabando ? _pulso.value : 0.0;
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.accion.withValues(alpha: 0.15 + 0.2 * t), width: 18 + 10 * t),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: c.gradPrincipal,
                            boxShadow: [BoxShadow(color: c.accion.withValues(alpha: 0.5), blurRadius: 30 * (0.5 + t))],
                          ),
                          child: Icon(Icons.mic_rounded, size: 72, color: c.accionTexto),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 28),
              Text(mmss(Duration(seconds: _seg)),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              Text('máximo ${_maximo}s', style: TextStyle(color: c.texto3, fontSize: 12)),
              const SizedBox(height: 18),
              Onda(niveles: List.of(_niveles), alto: 70),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _grabando ? _detener : null,
                  icon: Icon(Icons.stop_rounded, color: c.accion),
                  label: Text('Detener y enviar',
                      style: TextStyle(color: c.texto, fontWeight: FontWeight.w700, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.accion, width: 2),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Atajo para abrir la grabadora desde cualquier pantalla.
Future<Grabacion?> abrirGrabadora(BuildContext context) =>
    Navigator.of(context).push<Grabacion>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const GrabarScreen()));

