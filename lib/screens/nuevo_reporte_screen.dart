import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../models/reporte.dart';
import '../services/servicios.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'grabar_screen.dart';

/// Crear un reporte: categoría + audio (opcional) + foto (opcional).
class NuevoReporteScreen extends StatefulWidget {
  const NuevoReporteScreen({super.key, required this.posicion});
  final LatLng posicion;
  @override
  State<NuevoReporteScreen> createState() => _NuevoReporteScreenState();
}

class _NuevoReporteScreenState extends State<NuevoReporteScreen> {
  Categoria _cat = Categoria.accidente;
  String _direccion = 'Buscando dirección…';
  String? _foto;
  Grabacion? _audio;
  final _desc = TextEditingController();
  final _player = AudioPlayer();
  bool _sonando = false;

  @override
  void initState() {
    super.initState();
    direccionDe(widget.posicion).then((d) {
      if (mounted) setState(() => _direccion = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _sonando = false);
    });
  }

  @override
  void dispose() {
    _desc.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, imageQuality: 70, maxWidth: 1600);
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final destino = '${dir.path}/foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(x.path).copy(destino);
      setState(() => _foto = destino);
    } catch (_) {
      _aviso('No se pudo abrir la cámara');
    }
  }

  Future<void> _grabar() async {
    final g = await abrirGrabadora(context);
    if (g != null) setState(() => _audio = g);
  }

  Future<void> _escuchar() async {
    if (_audio == null) return;
    if (_sonando) {
      await _player.stop();
      setState(() => _sonando = false);
    } else {
      await _player.play(DeviceFileSource(_audio!.path));
      setState(() => _sonando = true);
    }
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _enviar() {
    final aj = context.read<AjustesStore>();
    Navigator.pop(
      context,
      Reporte(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        categoria: _cat,
        direccion: _direccion,
        descripcion: _desc.text.trim(),
        lat: widget.posicion.latitude,
        lng: widget.posicion.longitude,
        fecha: DateTime.now(),
        audioPath: _audio?.path,
        audioSegundos: _audio?.segundos,
        fotoPath: _foto,
        autor: aj.nombre,
        avatar: aj.avatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo reporte')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        // ---- Foto
        GestureDetector(
          onTap: () => _tomarFoto(ImageSource.camera),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RS.r14),
            child: Container(
              height: 190,
              color: c.elevada,
              child: _foto != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.file(File(_foto!), fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: BotonMapa(
                            icono: Icons.close_rounded, onTap: () => setState(() => _foto = null)),
                      ),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, size: 40, color: c.texto2),
                      const SizedBox(height: 8),
                      Text('Toca para tomar una foto (opcional)', style: TextStyle(color: c.texto2)),
                      TextButton(
                          onPressed: () => _tomarFoto(ImageSource.gallery),
                          child: Text('o elegir de la galería', style: TextStyle(color: c.accion))),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ---- Categoría
        const Text('¿Qué está pasando?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            for (final cat in Categoria.values)
              _OpcionCategoria(
                  cat: cat, activa: cat == _cat, onTap: () => setState(() => _cat = cat)),
          ],
        ),
        const SizedBox(height: 18),

        // ---- Ubicación
        Tarjeta(
          child: Row(children: [
            IconoCategoria(_cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cat.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_direccion, style: TextStyle(color: c.texto2, fontSize: 13)),
                Text('ahora', style: TextStyle(color: c.texto3, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ---- Audio
        Tarjeta(
          child: _audio == null
              ? InkWell(
                  onTap: _grabar,
                  child: Row(children: [
                    CircleAvatar(
                        radius: 22,
                        backgroundColor: Categoria.audio.color,
                        child: const Icon(Icons.mic_rounded, color: Colors.white)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Grabar un audio para los demás conductores',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.texto3),
                  ]),
                )
              : Row(children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: c.accion),
                    onPressed: _escuchar,
                    icon: Icon(_sonando ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: c.accionTexto),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Onda(niveles: Onda.falsa(_audio!.segundos, 30), alto: 36)),
                  const SizedBox(width: 8),
                  Text(mmss(Duration(seconds: _audio!.segundos)),
                      style: TextStyle(color: c.texto2)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => _audio = null)),
                ]),
        ),
        const SizedBox(height: 12),

        // ---- Descripción
        TextField(
          controller: _desc,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'Detalles (opcional)',
            filled: true,
            fillColor: c.superficie,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RS.r14),
                borderSide: BorderSide(color: c.borde)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RS.r14),
                borderSide: BorderSide(color: c.borde)),
          ),
        ),
        const SizedBox(height: 22),
        BotonPrincipal(texto: 'Enviar reporte', onTap: _enviar),
      ]),
    );
  }
}

class _OpcionCategoria extends StatelessWidget {
  const _OpcionCategoria({required this.cat, required this.activa, required this.onTap});
  final Categoria cat;
  final bool activa;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: activa ? cat.color.withValues(alpha: 0.15) : c.superficie,
      borderRadius: BorderRadius.circular(RS.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(RS.r14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RS.r14),
            border: Border.all(color: activa ? cat.color : c.borde, width: activa ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconoCategoria(cat, tam: 40),
            const SizedBox(height: 8),
            Text(cat.corto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
