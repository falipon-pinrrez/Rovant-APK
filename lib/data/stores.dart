import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reporte.dart';

/// Ajustes de la app (tema, alertas de voz, etc.). Se guardan en el teléfono.
class AjustesStore extends ChangeNotifier {
  late SharedPreferences _p;

  /// Elección del usuario. ThemeMode.system = automático por hora.
  ThemeMode themeMode = ThemeMode.system;

  /// Claro de 6:00 a. m. a 5:59 p. m.; oscuro de 6:00 p. m. a 5:59 a. m.
  static bool esDeNoche([DateTime? t]) {
    final h = (t ?? DateTime.now()).hour;
    return h >= 18 || h < 6;
  }

  /// Tema que se aplica en este momento.
  ThemeMode get temaEfectivo => themeMode == ThemeMode.system
      ? (esDeNoche() ? ThemeMode.dark : ThemeMode.light)
      : themeMode;
  bool notificaciones = true;
  bool audioAuto = true; // reproducir audios de reportes cercanos
  bool vozNavegacion = true; // instrucciones de giro habladas
  int radioAlerta = 400; // metros
  String nombre = 'Conductor';
  bool onboardingVisto = false;
  String avatar = 'assets/personajes/hola.png';
  /// Vehículo que se ve en el mapa (assets/vehiculos/<nombre>.png).
  String vehiculo = 'rovi';
  final Map<String, String> _lugares = {}; // casa / trabajo -> "lat|lng|nombre"

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_p.getInt('tema') ?? ThemeMode.system.index];
    notificaciones = _p.getBool('notificaciones') ?? true;
    audioAuto = _p.getBool('audioAuto') ?? true;
    vozNavegacion = _p.getBool('vozNavegacion') ?? true;
    radioAlerta = _p.getInt('radioAlerta') ?? 400;
    nombre = _p.getString('nombre') ?? 'Conductor';
    onboardingVisto = _p.getBool('onboarding2') ?? false;
    avatar = _p.getString('avatar2') ?? avatar;
    vehiculo = _p.getString('vehiculo2') ?? vehiculo;
    for (final k in const ['casa', 'trabajo']) {
      final v = _p.getString('lugar_$k');
      if (v != null) _lugares[k] = v;
    }
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _p.setInt('tema', m.index);
    notifyListeners();
  }

  void setNotificaciones(bool v) {
    notificaciones = v;
    _p.setBool('notificaciones', v);
    notifyListeners();
  }

  void setAudioAuto(bool v) {
    audioAuto = v;
    _p.setBool('audioAuto', v);
    notifyListeners();
  }

  void setVozNavegacion(bool v) {
    vozNavegacion = v;
    _p.setBool('vozNavegacion', v);
    notifyListeners();
  }

  void setRadio(int m) {
    radioAlerta = m;
    _p.setInt('radioAlerta', m);
    notifyListeners();
  }

  void setNombre(String n) {
    nombre = n.trim().isEmpty ? 'Conductor' : n.trim();
    _p.setString('nombre', nombre);
    notifyListeners();
  }

  void setAvatar(String a) {
    avatar = a;
    _p.setString('avatar2', a);
    notifyListeners();
  }

  void setVehiculo(String v) {
    vehiculo = v;
    _p.setString('vehiculo2', v);
    notifyListeners();
  }

  /// Lugar guardado (casa o trabajo): (lat, lng, nombre) o null.
  (double, double, String)? lugar(String clave) {
    final v = _lugares[clave];
    if (v == null) return null;
    final partes = v.split('|');
    return (double.parse(partes[0]), double.parse(partes[1]), partes.sublist(2).join('|'));
  }

  void guardarLugar(String clave, double lat, double lng, String nombre) {
    _lugares[clave] = '$lat|$lng|$nombre';
    _p.setString('lugar_$clave', _lugares[clave]!);
    notifyListeners();
  }

  void borrarLugar(String clave) {
    _lugares.remove(clave);
    _p.remove('lugar_$clave');
    notifyListeners();
  }

  void marcarOnboarding() {
    onboardingVisto = true;
    _p.setBool('onboarding2', true);
    notifyListeners();
  }
}

/// Reportes de la vía. Hoy se guardan en el teléfono; para que todos los
/// conductores vean los reportes de los demás, conecta este store a un
/// backend (Firebase Firestore + Storage es lo más rápido). Ver README.
class ReportesStore extends ChangeNotifier {
  late SharedPreferences _p;
  final List<Reporte> _items = [];

  /// Reporte que el mapa debe enfocar (al tocar "Ver en mapa").
  Reporte? foco;

  List<Reporte> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('reportes');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _items.addAll(list.map(Reporte.fromJson));
    }
    // Los reportes caducan a las 24 h, como en Waze.
    final limite = DateTime.now().subtract(const Duration(hours: 24));
    _items.removeWhere((r) => r.fecha.isBefore(limite));
    if (!(_p.getBool('demo') ?? false)) {
      _sembrarDemo();
      _p.setBool('demo', true);
    }
    _ordenar();
    _guardar();
  }

  void agregar(Reporte r) {
    _items.add(r);
    _ordenar();
    _guardar();
    notifyListeners();
  }

  void eliminar(Reporte r) {
    _items.removeWhere((x) => x.id == r.id);
    for (final p in [r.audioPath, r.fotoPath]) {
      if (p != null) {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      }
    }
    _guardar();
    notifyListeners();
  }

  void borrarTodo() {
    for (final r in List.of(_items)) {
      eliminar(r);
    }
  }

  void enfocar(Reporte r) {
    foco = r;
    notifyListeners();
  }

  void _ordenar() => _items.sort((a, b) => b.fecha.compareTo(a.fecha));

  void _guardar() =>
      _p.setString('reportes', jsonEncode(_items.map((r) => r.toJson()).toList()));

  /// Reportes de ejemplo en Bogotá para que el mapa no arranque vacío.
  void _sembrarDemo() {
    final now = DateTime.now();
    Reporte r(String id, Categoria c, String dir, String desc, double lat,
            double lng, int min) =>
        Reporte(
          id: 'demo-$id',
          categoria: c,
          direccion: dir,
          descripcion: desc,
          lat: lat,
          lng: lng,
          fecha: now.subtract(Duration(minutes: min)),
          autor: 'Comunidad',
        );
    _items.addAll([
      r('1', Categoria.accidente, 'Av. Caracas con Calle 72',
          'Choque entre dos carros, carril izquierdo cerrado.', 4.6566, -74.0646, 2),
      r('2', Categoria.trafico, 'Calle 68', 'Trancón de varios minutos.', 4.6672, -74.0712, 5),
      r('3', Categoria.policia, 'Autopista Norte', 'Retén en el costado oriental.',
          4.6905, -74.0560, 8),
      r('4', Categoria.obstaculo, 'Calle 68', 'Hueco grande en el carril derecho.',
          4.6650, -74.0790, 12),
      r('5', Categoria.audio, 'Zona de obras en la vía',
          'En la autopista, mejor tomar la salida.', 4.6810, -74.0590, 18),
    ]);
  }
}
