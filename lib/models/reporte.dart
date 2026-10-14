import 'package:flutter/material.dart';

enum Categoria { accidente, trafico, policia, obstaculo, foto, audio }

extension CategoriaX on Categoria {
  String get nombre => const {
        Categoria.accidente: 'Accidente',
        Categoria.trafico: 'Tráfico pesado',
        Categoria.policia: 'Policía',
        Categoria.obstaculo: 'Obstáculo',
        Categoria.foto: 'Foto',
        Categoria.audio: 'Audio',
      }[this]!;

  /// Nombre corto para los chips de filtro.
  String get corto => this == Categoria.trafico ? 'Tráfico' : nombre;

  Color get color => const {
        Categoria.accidente: Color(0xFFE53935),
        Categoria.trafico: Color(0xFFF57C1F),
        Categoria.policia: Color(0xFF2F6FED),
        Categoria.obstaculo: Color(0xFFF5A623),
        Categoria.foto: Color(0xFF7C4DFF),
        Categoria.audio: Color(0xFF43A047),
      }[this]!;

  IconData get icono => const {
        Categoria.accidente: Icons.car_crash_rounded,
        Categoria.trafico: Icons.traffic_rounded,
        Categoria.policia: Icons.local_police_rounded,
        Categoria.obstaculo: Icons.warning_rounded,
        Categoria.foto: Icons.photo_camera_rounded,
        Categoria.audio: Icons.graphic_eq_rounded,
      }[this]!;

  /// Frase que se dice en voz alta cuando te acercas.
  String frase(int metros) => switch (this) {
        Categoria.accidente => 'Atención, accidente reportado a $metros metros',
        Categoria.trafico => 'Tráfico pesado a $metros metros',
        Categoria.policia => 'Policía reportada a $metros metros',
        Categoria.obstaculo => 'Cuidado, obstáculo en la vía a $metros metros',
        Categoria.foto => 'Reporte con foto a $metros metros',
        Categoria.audio => 'Mensaje de voz a $metros metros',
      };
}

class Reporte {
  Reporte({
    required this.id,
    required this.categoria,
    required this.direccion,
    required this.lat,
    required this.lng,
    required this.fecha,
    this.descripcion = '',
    this.audioPath,
    this.audioSegundos,
    this.fotoPath,
    this.autor = 'Tú',
    this.avatar,
  });

  final String id;
  final Categoria categoria;
  final String direccion;
  final String descripcion;
  final double lat, lng;
  final DateTime fecha;
  final String? audioPath;
  final int? audioSegundos;
  final String? fotoPath;
  final String autor;
  /// Ruta del personaje (asset) de quien reportó.
  final String? avatar;

  bool get tieneAudio => audioPath != null && audioPath!.isNotEmpty;
  bool get tieneFoto => fotoPath != null && fotoPath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': categoria.name,
        'direccion': direccion,
        'descripcion': descripcion,
        'lat': lat,
        'lng': lng,
        'fecha': fecha.toIso8601String(),
        'audioPath': audioPath,
        'audioSegundos': audioSegundos,
        'fotoPath': fotoPath,
        'autor': autor,
        'avatar': avatar,
      };

  factory Reporte.fromJson(Map<String, dynamic> j) => Reporte(
        id: j['id'] as String,
        categoria: Categoria.values.firstWhere((c) => c.name == j['categoria'],
            orElse: () => Categoria.obstaculo),
        direccion: (j['direccion'] ?? '') as String,
        descripcion: (j['descripcion'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        fecha: DateTime.parse(j['fecha'] as String),
        audioPath: j['audioPath'] as String?,
        audioSegundos: j['audioSegundos'] as int?,
        fotoPath: j['fotoPath'] as String?,
        autor: (j['autor'] ?? 'Tú') as String,
        avatar: j['avatar'] as String?,
      );
}

String hace(DateTime f) {
  final d = DateTime.now().difference(f);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  return '${d.inDays} d';
}

String mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String distanciaTexto(double metros) {
  if (metros < 1000) return '${(metros / 10).round() * 10} m';
  return '${(metros / 1000).toStringAsFixed(1)} km';
}
