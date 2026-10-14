import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/stores.dart';
import '../models/reporte.dart';
import '../services/servicios.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'home_shell.dart';

/// Detalle de un reporte: reproductor de audio, foto y acciones.
class DetalleReporteScreen extends StatefulWidget {
  const DetalleReporteScreen({super.key, required this.reporte});
  final Reporte reporte;
  @override
  State<DetalleReporteScreen> createState() => _DetalleReporteScreenState();
}

class _DetalleReporteScreenState extends State<DetalleReporteScreen> {
  final _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _sonando = false;

  Reporte get r => widget.reporte;
  bool get _audioDisponible => r.tieneAudio && File(r.audioPath!).existsSync();

  @override
  void initState() {
    super.initState();
    if (r.audioSegundos != null) _dur = Duration(seconds: r.audioSegundos!);
    if (_audioDisponible) {
      _player.setSource(DeviceFileSource(r.audioPath!));
      _subs.addAll([
        _player.onPositionChanged.listen((p) => setState(() => _pos = p)),
        _player.onDurationChanged.listen((d) => setState(() => _dur = d)),
        _player.onPlayerStateChanged
            .listen((s) => setState(() => _sonando = s == PlayerState.playing)),
        _player.onPlayerComplete.listen((_) => setState(() => _pos = Duration.zero)),
      ]);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    Voz.instancia.callar();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (!_audioDisponible) {
      // Sin audio grabado: lo leemos en voz alta.
      await Voz.instancia
          .decir('${r.categoria.nombre}. ${r.direccion}. ${r.descripcion}');
      return;
    }
    if (_sonando) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _saltar(int seg) async {
    if (!_audioDisponible) return;
    var nueva = _pos + Duration(seconds: seg);
    if (nueva < Duration.zero) nueva = Duration.zero;
    if (nueva > _dur) nueva = _dur;
    await _player.seek(nueva);
  }

  void _compartir() {
    final texto = 'Rovant: ${r.categoria.nombre} en ${r.direccion} (${hace(r.fecha)}). '
        '${r.descripcion}\nhttps://maps.google.com/?q=${r.lat},${r.lng}';
    final archivos = <XFile>[
      if (r.tieneFoto && File(r.fotoPath!).existsSync()) XFile(r.fotoPath!),
      if (_audioDisponible) XFile(r.audioPath!),
    ];
    if (archivos.isEmpty) {
      Share.share(texto);
    } else {
      Share.shareXFiles(archivos, text: texto);
    }
  }

  void _verEnMapa() {
    context.read<ReportesStore>().enfocar(r);
    pestana.value = 0;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: const Text('¿Seguro que quieres eliminar este reporte?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ReportesStore>().eliminar(r);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    final total = _dur.inMilliseconds == 0 ? 1 : _dur.inMilliseconds;
    final progreso = (_pos.inMilliseconds / total).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(r.tieneFoto ? 'Reporte con foto' : (r.tieneAudio ? 'Audio' : r.categoria.nombre)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) => v == 'del' ? _eliminar() : null,
            itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Eliminar'))],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        if (r.tieneFoto && File(r.fotoPath!).existsSync()) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(RS.r14),
            child: Image.file(File(r.fotoPath!), height: 230, fit: BoxFit.cover),
          ),
          const SizedBox(height: 18),
        ] else ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.accion.withValues(alpha: 0.18), width: 16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: r.tieneAudio ? c.gradPrincipal : null,
                    color: r.tieneAudio ? null : r.categoria.color,
                  ),
                  child: Icon(r.tieneAudio ? Icons.graphic_eq_rounded : r.categoria.icono,
                      size: 64, color: r.tieneAudio ? c.accionTexto : Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],

        Text(r.categoria.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        if (r.descripcion.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(r.descripcion,
              textAlign: TextAlign.center, style: TextStyle(color: c.texto2, fontSize: 15)),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Avatar(r.avatar, tam: 26),
          const SizedBox(width: 8),
          Text('${r.autor} · hace ${hace(r.fecha)}',
              style: TextStyle(color: c.texto3, fontSize: 12)),
        ]),
        const SizedBox(height: 22),

        // ---- Reproductor
        if (_audioDisponible) ...[
          Onda(niveles: Onda.falsa(r.id.hashCode), progreso: progreso, alto: 48),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accion,
              inactiveTrackColor: c.borde,
              thumbColor: c.accion,
              trackHeight: 3,
            ),
            child: Slider(
              value: progreso,
              onChanged: (v) =>
                  _player.seek(Duration(milliseconds: (v * _dur.inMilliseconds).round())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(mmss(_pos), style: TextStyle(color: c.texto3, fontSize: 12)),
              Text(mmss(_dur), style: TextStyle(color: c.texto3, fontSize: 12)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              iconSize: 34,
              onPressed: _audioDisponible ? () => _saltar(-10) : null,
              icon: const Icon(Icons.replay_10_rounded)),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: _playPause,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.suave,
                border: Border.all(color: c.accion, width: 2),
              ),
              child: Icon(
                  _audioDisponible
                      ? (_sonando ? Icons.pause_rounded : Icons.play_arrow_rounded)
                      : Icons.record_voice_over_rounded,
                  size: 40,
                  color: c.accion),
            ),
          ),
          const SizedBox(width: 18),
          IconButton(
              iconSize: 34,
              onPressed: _audioDisponible ? () => _saltar(10) : null,
              icon: const Icon(Icons.forward_10_rounded)),
        ]),
        if (!_audioDisponible)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Toca para escucharlo en voz alta',
                textAlign: TextAlign.center, style: TextStyle(color: c.texto3, fontSize: 12)),
          ),
        const SizedBox(height: 24),

        // ---- Ubicación y acciones
        Tarjeta(
          child: Row(children: [
            Icon(Icons.place_rounded, color: c.texto),
            const SizedBox(width: 10),
            Expanded(child: Text(r.direccion, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Accion(Icons.share_rounded, 'Compartir', _compartir),
          const SizedBox(width: 10),
          _Accion(Icons.map_rounded, 'Ver en mapa', _verEnMapa),
          const SizedBox(width: 10),
          _Accion(Icons.delete_outline_rounded, 'Eliminar', _eliminar),
        ]),
      ]),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion(this.icono, this.texto, this.onTap);
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Tarjeta(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(icono, color: context.rs.texto),
            const SizedBox(height: 6),
            Text(texto, style: TextStyle(fontSize: 12, color: context.rs.texto2)),
          ]),
        ),
      );
}
