import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'home_shell.dart';

/// Pantalla de inicio con Rovi, la mascota de Rovant.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with SingleTickerProviderStateMixin {
  bool _cargando = false;
  late final AnimationController _flotar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _flotar.dispose();
    super.dispose();
  }

  Future<void> _comenzar() async {
    setState(() => _cargando = true);
    try {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) await Geolocator.requestPermission();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: c.oscuro
                ? const [Color(0xFF0D1015), Color(0xFF13213A), Color(0xFF0D1015)]
                : const [Color(0xFFF8FBFF), Color(0xFFCFE0FB), Color(0xFFEEF3FB)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _flotar,
                builder: (_, child) => Transform.translate(
                    offset: Offset(0, -8 * Curves.easeInOut.transform(_flotar.value)),
                    child: child),
                child: Image.asset('assets/mascota.png', height: 230),
              ),
              const SizedBox(height: 18),
              const LogoRovant(alto: 52),
              const SizedBox(height: 10),
              Text('Tu camino, más simple',
                  style: TextStyle(color: c.texto, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Reporta lo que pasa en la vía con tu voz',
                  style: TextStyle(color: c.texto2, fontSize: 13)),
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: c.superficie.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(RS.r20),
                  border: Border.all(color: c.borde),
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
              const SizedBox(height: 10),
              TextButton(
                onPressed: _comenzar,
                child: Text('Iniciar sesión',
                    style: TextStyle(
                        color: c.texto,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
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
          Icon(icono, color: context.rs.accion, size: 26),
          const SizedBox(height: 6),
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.rs.texto2, height: 1.3)),
        ]),
      );
}
