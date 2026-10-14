import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../services/servicios.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Perfil y configuración.
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    final aj = context.watch<AjustesStore>();
    final temaTxt = switch (aj.themeMode) {
      ThemeMode.dark => 'Oscuro',
      ThemeMode.light => 'Claro',
      ThemeMode.system => 'Sistema',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        // ---- Perfil
        Tarjeta(
          onTap: () => _elegirPersonaje(context),
          child: Row(children: [
            Avatar(aj.avatar, tam: 64, anillo: c.accion),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(aj.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Toca para cambiar tu personaje',
                    style: TextStyle(color: c.texto2, fontSize: 13)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.texto3),
          ]),
        ),

        const _Seccion('Cuenta'),
        _Grupo(children: [
          _Fila(
              icono: Icons.person_rounded,
              texto: 'Editar perfil',
              onTap: () => _editarNombre(context, aj)),
          _Fila(
            icono: Icons.notifications_rounded,
            texto: 'Notificaciones',
            trailing: Switch(value: aj.notificaciones, onChanged: aj.setNotificaciones),
          ),
          _Fila(
            icono: Icons.shield_rounded,
            texto: 'Privacidad y seguridad',
            onTap: () => _info(context, 'Privacidad y seguridad',
                'Tus reportes, audios y fotos se guardan en tu teléfono y se borran solos a las 24 horas. '
                    'La ubicación solo se usa mientras la app está abierta para navegar y avisarte de reportes cercanos.'),
          ),
        ]),

        const _Seccion('Aplicación'),
        _Grupo(children: [
          _Fila(
              icono: Icons.dark_mode_rounded,
              texto: 'Tema',
              valor: temaTxt,
              onTap: () => _elegirTema(context, aj)),
          const _Fila(icono: Icons.language_rounded, texto: 'Idioma', valor: 'Español'),
          _Fila(
            icono: Icons.campaign_rounded,
            texto: 'Alertas con audio',
            trailing: Switch(value: aj.audioAuto, onChanged: aj.setAudioAuto),
          ),
          _Fila(
            icono: Icons.record_voice_over_rounded,
            texto: 'Voz de navegación',
            trailing: Switch(value: aj.vozNavegacion, onChanged: aj.setVozNavegacion),
          ),
          _Fila(
              icono: Icons.radar_rounded,
              texto: 'Distancia de alerta',
              valor: '${aj.radioAlerta} m',
              onTap: () => _elegirRadio(context, aj)),
          _Fila(
              icono: Icons.volume_up_rounded,
              texto: 'Probar voz',
              onTap: () => Voz.instancia.decir('Hola ${aj.nombre}, Rovant está listo para el camino.')),
        ]),

        const _Seccion('Soporte'),
        _Grupo(children: [
          _Fila(
            icono: Icons.help_rounded,
            texto: 'Centro de ayuda',
            onTap: () => _info(context, 'Centro de ayuda',
                '• Mantén presionado el mapa o usa "¿A dónde vas?" para navegar.\n'
                    '• Botón rojo: reportar accidente, tráfico, policía u obstáculo.\n'
                    '• Botón verde: grabar un audio rápido en tu ubicación.\n'
                    '• Al acercarte a un reporte, Rovant te avisa con voz y reproduce el audio.\n\n'
                    'Escríbenos: soporte@rovant.app'),
          ),
          _Fila(
            icono: Icons.description_rounded,
            texto: 'Términos y condiciones',
            onTap: () => _info(context, 'Términos y condiciones',
                'Usa Rovant con responsabilidad: no manipules el teléfono mientras conduces. '
                    'Graba audios solo cuando estés detenido o pídele a un acompañante que lo haga.'),
          ),
          _Fila(
            icono: Icons.delete_sweep_rounded,
            texto: 'Borrar mis reportes',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Borrar reportes'),
                  content: const Text('Se eliminarán todos los reportes, audios y fotos guardados.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                  ],
                ),
              );
              if (ok == true && context.mounted) context.read<ReportesStore>().borrarTodo();
            },
          ),
        ]),
        const SizedBox(height: 24),
        const Center(child: LogoRovant(alto: 26)),
        const SizedBox(height: 6),
        Center(child: Text('Versión 1.0.0', style: TextStyle(color: c.texto3, fontSize: 12))),
      ]),
    );
  }

  Future<void> _elegirPersonaje(BuildContext context) async {
    final aj = context.read<AjustesStore>();
    final lista = await cargarPersonajes();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Elige tu personaje',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final a in lista)
                GestureDetector(
                  onTap: () {
                    aj.setAvatar(a);
                    Navigator.pop(ctx);
                  },
                  child: Avatar(a,
                      tam: 72, anillo: a == aj.avatar ? ctx.rs.accion : null),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _editarNombre(BuildContext context, AjustesStore aj) async {
    final ctrl = TextEditingController(text: aj.nombre);
    final n = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (n != null) aj.setNombre(n);
  }

  void _elegirTema(BuildContext context, AjustesStore aj) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (m, t) in const [
            (ThemeMode.dark, 'Oscuro'),
            (ThemeMode.light, 'Claro'),
            (ThemeMode.system, 'Según el sistema'),
          ])
            ListTile(
              title: Text(t),
              trailing: aj.themeMode == m ? Icon(Icons.check_rounded, color: ctx.rs.accion) : null,
              onTap: () {
                aj.setTheme(m);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  void _elegirRadio(BuildContext context, AjustesStore aj) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in const [200, 400, 800, 1500])
            ListTile(
              title: Text('$m metros'),
              trailing: aj.radioAlerta == m ? Icon(Icons.check_rounded, color: ctx.rs.accion) : null,
              onTap: () {
                aj.setRadio(m);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  void _info(BuildContext context, String titulo, String texto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(RS.r14),
        border: Border.all(color: c.borde),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 52, color: c.borde),
          children[i],
        ],
      ]),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.texto, this.valor, this.trailing, this.onTap});
  final IconData icono;
  final String texto;
  final String? valor;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return ListTile(
      onTap: onTap,
      leading: Icon(icono, color: c.texto, size: 22),
      title: Text(texto, style: const TextStyle(fontSize: 15)),
      trailing: trailing ??
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (valor != null) Text(valor!, style: TextStyle(color: c.texto2, fontSize: 13)),
            if (onTap != null || valor != null) Icon(Icons.chevron_right_rounded, color: c.texto3),
          ]),
    );
  }
}
