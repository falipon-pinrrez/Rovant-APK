import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const _ua = 'Rovant/1.0 (app de navegacion)';

/// Voz de la app: lee instrucciones y reproduce los audios de los reportes.
class Voz {
  Voz._();
  static final instancia = Voz._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _listo = false;

  Future<void> _init() async {
    if (_listo) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    _listo = true;
  }

  Future<void> decir(String texto) async {
    await _init();
    await _tts.stop();
    await _tts.speak(texto);
  }

  /// Alerta de un reporte: dice la frase y, si hay audio grabado, lo reproduce.
  Future<void> alerta(String frase, String? audioPath) async {
    if (frase.isNotEmpty) await decir(frase);
    if (audioPath != null && File(audioPath).existsSync()) {
      await _player.stop();
      await _player.play(DeviceFileSource(audioPath));
    }
  }

  Future<void> callar() async {
    await _tts.stop();
    await _player.stop();
  }
}

/// Dirección legible a partir de coordenadas (OpenStreetMap Nominatim).
Future<String> direccionDe(LatLng p) async {
  try {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&zoom=17&accept-language=es&lat=${p.latitude}&lon=${p.longitude}');
    final res = await http.get(uri, headers: {'User-Agent': _ua}).timeout(
        const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final a = (jsonDecode(res.body)['address'] ?? {}) as Map<String, dynamic>;
      final via = a['road'] ?? a['pedestrian'] ?? a['neighbourhood'];
      final zona = a['neighbourhood'] ?? a['suburb'] ?? a['city'];
      if (via != null) return zona != null && zona != via ? '$via, $zona' : '$via';
    }
  } catch (_) {}
  return '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
}

class Paso {
  Paso(this.punto, this.texto, this.icono, this.calle);
  final LatLng punto;
  final String texto;
  final IconData icono;
  final String calle;
}

class Ruta {
  Ruta(this.puntos, this.metros, this.segundos, this.pasos);
  final List<LatLng> puntos;
  final double metros;
  final double segundos;
  final List<Paso> pasos;
}

/// Calcula una ruta en carro con OSRM (servidor público de demostración).
/// Para producción usa tu propio servidor OSRM, GraphHopper o Mapbox.
Future<Ruta?> calcularRuta(LatLng a, LatLng b) async {
  try {
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final res = await http.get(uri, headers: {'User-Agent': _ua}).timeout(
        const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = j['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final r = routes.first as Map<String, dynamic>;
    final coords = (r['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final pasos = <Paso>[];
    for (final s in (r['legs'][0]['steps'] as List)) {
      final m = s['maneuver'] as Map<String, dynamic>;
      final loc = m['location'] as List;
      final calle = (s['name'] ?? '') as String;
      final (texto, icono) = _instruccion(
          m['type'] as String? ?? '', m['modifier'] as String? ?? '', calle);
      pasos.add(Paso(LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          texto, icono, calle));
    }
    return Ruta(coords, (r['distance'] as num).toDouble(),
        (r['duration'] as num).toDouble(), pasos);
  } catch (_) {
    return null;
  }
}

(String, IconData) _instruccion(String tipo, String mod, String calle) {
  final por = calle.isEmpty ? '' : ' por $calle';
  if (tipo == 'arrive') return ('Llegaste a tu destino', Icons.flag_rounded);
  if (tipo == 'depart') return ('Sal$por', Icons.navigation_rounded);
  if (tipo == 'roundabout' || tipo == 'rotary') {
    return ('Toma la glorieta$por', Icons.roundabout_right_rounded);
  }
  return switch (mod) {
    'right' => ('Gira a la derecha$por', Icons.turn_right_rounded),
    'left' => ('Gira a la izquierda$por', Icons.turn_left_rounded),
    'slight right' => ('Mantente a la derecha$por', Icons.turn_slight_right_rounded),
    'slight left' => ('Mantente a la izquierda$por', Icons.turn_slight_left_rounded),
    'sharp right' => ('Gira fuerte a la derecha$por', Icons.turn_sharp_right_rounded),
    'sharp left' => ('Gira fuerte a la izquierda$por', Icons.turn_sharp_left_rounded),
    'uturn' => ('Da la vuelta en U', Icons.u_turn_left_rounded),
    _ => ('Continúa recto$por', Icons.straight_rounded),
  };
}

/// Personajes (avatares) disponibles: todo PNG/JPG/WEBP dentro de
/// assets/personajes/. Para añadir tus propios personajes, copia las imágenes
/// a esa carpeta y vuelve a compilar.
Future<List<String>> cargarPersonajes() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final lista = manifest
      .listAssets()
      .where((a) => a.startsWith('assets/personajes/'))
      .where((a) => RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(a))
      .toList()
    ..sort();
  return lista;
}

class Lugar {
  Lugar(this.nombre, this.detalle, this.punto);
  final String nombre;
  final String detalle;
  final LatLng punto;
}

/// Búsqueda de destinos (OpenStreetMap Nominatim), priorizando cerca de ti.
Future<List<Lugar>> buscarLugares(String q, LatLng? cerca, {bool soloCerca = false}) async {
  try {
    var url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8'
        '&accept-language=es&q=${Uri.encodeQueryComponent(q)}';
    if (cerca != null) {
      final d = soloCerca ? 0.05 : 0.5; // ~5 km o ~50 km
      url += '&viewbox=${cerca.longitude - d},${cerca.latitude + d},'
          '${cerca.longitude + d},${cerca.latitude - d}';
      if (soloCerca) url += '&bounded=1';
    }
    final res = await http.get(Uri.parse(url), headers: {'User-Agent': _ua}).timeout(
        const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    return (jsonDecode(res.body) as List).map((e) {
      final partes = ((e['display_name'] ?? '') as String).split(', ');
      return Lugar(
        partes.first,
        partes.skip(1).take(3).join(', '),
        LatLng(double.parse(e['lat'] as String), double.parse(e['lon'] as String)),
      );
    }).toList();
  } catch (_) {
    return [];
  }
}
