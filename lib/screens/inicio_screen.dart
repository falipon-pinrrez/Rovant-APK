import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'home_shell.dart';

/// Pantalla de inicio (onboarding).
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  bool _cargando = false;

  Future<void> _comenzar() async {
    setState(() => _cargando = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    } catch (_) {}
    if (!mounted) return;
    context.read<AjustesStore>().marcarOnboarding();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Paisaje(c.oscuro))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const Spacer(flex: 2),
              Image.asset('assets/icono.png', width: 96, height: 96),
              const SizedBox(height: 18),
              const LogoRovant(alto: 52, forzarBlanco: true),
              const SizedBox(height: 10),
              const Text('Tu camino, más seguro',
                  style: TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('Reporta lo que pasa en la vía con tu voz',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
              const Spacer(flex: 3),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: c.superficie.withValues(alpha: c.oscuro ? 0.85 : 0.95),
                  borderRadius: BorderRadius.circular(RS.r20),
                ),
                child: const Row(children: [
                  _Rasgo(Icons.near_me_rounded, 'Navegación\ninteligente'),
                  _Rasgo(Icons.record_voice_over_rounded, 'Alertas\ncon audio'),
                  _Rasgo(Icons.shield_rounded, 'Alertas de\nseguridad'),
                ]),
              ),
              const SizedBox(height: 20),
              BotonPrincipal(
                  texto: 'Comenzar',
                  icono: Icons.arrow_forward_rounded,
                  cargando: _cargando,
                  onTap: _comenzar),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _comenzar,
                child: Text('Iniciar sesión',
                    style: TextStyle(
                        color: c.oscuro ? Colors.white : c.texto,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Rasgo extends StatelessWidget {
  const _Rasgo(this.icono, this.texto);
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icono, color: RS.dorado, size: 26),
          const SizedBox(height: 6),
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.rs.texto2, height: 1.3)),
        ]),
      );
}

/// Fondo ilustrado: cielo, montañas y carretera con línea central dorada.
class _Paisaje extends CustomPainter {
  _Paisaje(this.oscuro);
  final bool oscuro;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: oscuro
                ? const [Color(0xFF0D1015), Color(0xFF2A2318), Color(0xFF6B4A22)]
                : const [Color(0xFF7FB2E6), Color(0xFFB9D6F0), Color(0xFFF2D9A6)],
          ).createShader(r));

    void montes(double base, double amp, Color col, int semilla) {
      final rnd = Random(semilla);
      final p = Path()..moveTo(0, s.height * base);
      for (var x = 0.0; x <= s.width; x += s.width / 6) {
        p.lineTo(x, s.height * (base - amp * (0.4 + rnd.nextDouble() * 0.6)));
      }
      p
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();
      canvas.drawPath(p, Paint()..color = col);
    }

    montes(0.52, 0.16, oscuro ? const Color(0xFF1E1A16) : const Color(0xFF8DA7C4), 3);
    montes(0.60, 0.10, oscuro ? const Color(0xFF15130F) : const Color(0xFF5E7F63), 7);

    // Carretera en perspectiva
    final cx = s.width / 2;
    final top = s.height * 0.55;
    final road = Path()
      ..moveTo(cx - 6, top)
      ..quadraticBezierTo(cx + 60, s.height * 0.72, cx - s.width * 0.7, s.height)
      ..lineTo(cx + s.width * 0.55, s.height)
      ..quadraticBezierTo(cx + 120, s.height * 0.72, cx + 6, top)
      ..close();
    canvas.drawPath(road, Paint()..color = oscuro ? const Color(0xFF1B1D22) : const Color(0xFF55606E));
    final linea = Path()
      ..moveTo(cx, top)
      ..quadraticBezierTo(cx + 90, s.height * 0.72, cx - s.width * 0.08, s.height);
    canvas.drawPath(
        linea,
        Paint()
          ..color = RS.dorado
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));

    // Velo para que el texto se lea bien
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          ).createShader(r));
  }

  @override
  bool shouldRepaint(covariant _Paisaje old) => old.oscuro != oscuro;
}
