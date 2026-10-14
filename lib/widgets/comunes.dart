import 'dart:math';

import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../theme.dart';

/// Logotipo Rovant (azul marino en tema claro, blanco en oscuro).
class LogoRovant extends StatelessWidget {
  const LogoRovant({super.key, this.alto = 44, this.forzarBlanco = false});
  final double alto;
  final bool forzarBlanco;
  @override
  Widget build(BuildContext context) {
    final blanco = forzarBlanco || context.rs.oscuro;
    return Image.asset(
      blanco ? 'assets/logo_oscuro.png' : 'assets/logo_claro.png',
      height: alto,
      fit: BoxFit.contain,
    );
  }
}

/// Botón principal en pastilla (degradado dorado en oscuro / azul en claro).
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal(
      {super.key, required this.texto, this.icono, this.onTap, this.cargando = false});
  final String texto;
  final IconData? icono;
  final VoidCallback? onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: c.gradPrincipal,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                  color: c.accion.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: cargando ? null : onTap,
            child: Center(
              child: cargando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: c.accionTexto))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(texto,
                          style: TextStyle(
                              color: c.accionTexto,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      if (icono != null) ...[
                        const SizedBox(width: 8),
                        Icon(icono, color: c.accionTexto, size: 20),
                      ],
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo de color de la categoría con el ícono en blanco.
class IconoCategoria extends StatelessWidget {
  const IconoCategoria(this.categoria, {super.key, this.tam = 44, this.borde = false});
  final Categoria categoria;
  final double tam;
  final bool borde;
  @override
  Widget build(BuildContext context) => Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          color: categoria.color,
          shape: BoxShape.circle,
          border: borde ? Border.all(color: Colors.white, width: 2.5) : null,
          boxShadow: borde
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6)]
              : null,
        ),
        child: Icon(categoria.icono, color: Colors.white, size: tam * 0.52),
      );
}

/// Personaje / avatar redondo.
class Avatar extends StatelessWidget {
  const Avatar(this.asset, {super.key, this.tam = 44, this.anillo});
  final String? asset;
  final double tam;
  final Color? anillo;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Container(
      width: tam,
      height: tam,
      padding: EdgeInsets.all(tam * 0.06),
      decoration: BoxDecoration(
        color: c.elevada,
        shape: BoxShape.circle,
        border: Border.all(color: anillo ?? c.borde, width: 2),
      ),
      child: ClipOval(
        child: asset == null
            ? Icon(Icons.person_rounded, color: c.texto2, size: tam * 0.6)
            : Image.asset(asset!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_rounded, color: c.texto2, size: tam * 0.6)),
      ),
    );
  }
}

/// Barras de onda de audio. [niveles] van de 0 a 1.
class Onda extends StatelessWidget {
  const Onda({super.key, required this.niveles, this.color, this.alto = 64, this.progreso});
  final List<double> niveles;
  final Color? color;
  final double alto;
  final double? progreso; // 0..1: barras ya reproducidas en color fuerte
  @override
  Widget build(BuildContext context) => SizedBox(
        height: alto,
        width: double.infinity,
        child: CustomPaint(
            painter: _OndaPainter(niveles, color ?? context.rs.accion, progreso)),
      );

  /// Onda "decorativa" estable a partir de una semilla.
  static List<double> falsa(int semilla, [int n = 48]) {
    final r = Random(semilla);
    return List.generate(n, (i) {
      final env = sin(pi * i / (n - 1));
      return (0.15 + r.nextDouble() * 0.85) * (0.35 + 0.65 * env);
    });
  }
}

class _OndaPainter extends CustomPainter {
  _OndaPainter(this.n, this.color, this.progreso);
  final List<double> n;
  final Color color;
  final double? progreso;
  @override
  void paint(Canvas canvas, Size s) {
    if (n.isEmpty) return;
    final paso = s.width / n.length;
    final ancho = max(2.0, paso * 0.45);
    for (var i = 0; i < n.length; i++) {
      final h = max(4.0, n[i].clamp(0.0, 1.0) * s.height);
      final x = i * paso + paso / 2;
      final activa = progreso == null || i / n.length <= progreso!;
      final p = Paint()
        ..color = activa ? color : color.withValues(alpha: 0.3)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ancho;
      canvas.drawLine(Offset(x, s.height / 2 - h / 2), Offset(x, s.height / 2 + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _OndaPainter old) =>
      old.n != n || old.progreso != progreso || old.color != color;
}

/// Botón cuadrado redondeado flotante del mapa.
class BotonMapa extends StatelessWidget {
  const BotonMapa(
      {super.key, required this.icono, required this.onTap, this.color, this.fondo});
  final IconData icono;
  final VoidCallback onTap;
  final Color? color;
  final Color? fondo;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: fondo ?? c.superficie.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 48, height: 48, child: Icon(icono, color: color ?? c.texto, size: 24)),
      ),
    );
  }
}

/// Tarjeta superficie estándar.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: c.superficie,
      borderRadius: BorderRadius.circular(RS.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(RS.r14),
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RS.r14),
            border: Border.all(color: c.borde),
          ),
          child: child,
        ),
      ),
    );
  }
}
