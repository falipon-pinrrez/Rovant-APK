import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../models/reporte.dart';
import '../services/servicios.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'detalle_reporte_screen.dart';
import 'grabar_screen.dart';
import 'nuevo_reporte_screen.dart';

const _bogota = LatLng(4.6573, -74.0647);

double _dist(LatLng a, LatLng b) =>
    Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

/// Mapa principal / navegación.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _map = MapController();
  bool _mapListo = false;
  LatLng? _pos;
  double _velocidad = 0;
  double _rumbo = 0;
  bool _seguir = true;
  StreamSubscription<Position>? _sub;

  Ruta? _ruta;
  LatLng? _destino;
  int _pasoIdx = 0;
  double _restante = 0;
  bool _calculando = false;
  final Set<int> _pasosDichos = {};

  final Set<String> _alertados = {};
  Reporte? _alerta;
  double _alertaDist = 0;
  Timer? _alertaTimer;

  late ReportesStore _store;

  @override
  void initState() {
    super.initState();
    _store = context.read<ReportesStore>();
    _store.addListener(_onStore);
    _iniciarUbicacion();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _alertaTimer?.cancel();
    _store.removeListener(_onStore);
    super.dispose();
  }

  // ---------------------------------------------------------------- ubicación

  Future<void> _iniciarUbicacion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _aviso('Activa el GPS para navegar');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _aviso('Rovant necesita tu ubicación para navegar');
        return;
      }
      _onPos(await Geolocator.getCurrentPosition());
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      ).listen(_onPos);
    } catch (_) {
      _aviso('No se pudo obtener tu ubicación');
    }
  }

  void _onPos(Position p) {
    if (!mounted) return;
    final nueva = LatLng(p.latitude, p.longitude);
    setState(() {
      _pos = nueva;
      _velocidad = max(0.0, p.speed * 3.6);
      if (p.heading > 0) _rumbo = p.heading;
    });
    if (_seguir && _mapListo) {
      _map.move(nueva, _ruta != null ? 17.0 : max(_map.camera.zoom, 15.0));
    }
    _revisarAlertas(nueva);
    _avanzarRuta(nueva);
  }

  void _onStore() {
    final f = _store.foco;
    if (f != null && _mapListo) {
      _seguir = false;
      _map.move(LatLng(f.lat, f.lng), 16.5);
      _store.foco = null;
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- alertas

  void _revisarAlertas(LatLng yo) {
    final aj = context.read<AjustesStore>();
    if (!aj.notificaciones) return;
    for (final r in _store.items) {
      if (_alertados.contains(r.id)) continue;
      final d = _dist(yo, LatLng(r.lat, r.lng));
      if (d <= aj.radioAlerta) {
        _alertados.add(r.id);
        _mostrarAlerta(r, d);
        if (aj.audioAuto) {
          Voz.instancia.alerta(r.categoria.frase((d / 10).round() * 10), r.audioPath);
        }
        break; // una alerta a la vez
      }
    }
  }

  void _mostrarAlerta(Reporte r, double d) {
    _alertaTimer?.cancel();
    setState(() {
      _alerta = r;
      _alertaDist = d;
    });
    _alertaTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _alerta = null);
    });
  }

  // ---------------------------------------------------------------- rutas

  Future<void> _trazar(LatLng destino, {bool recalculo = false}) async {
    final yo = _pos;
    if (yo == null) {
      _aviso('Esperando tu ubicación…');
      return;
    }
    final aj = context.read<AjustesStore>();
    setState(() {
      _calculando = true;
      _destino = destino;
    });
    final r = await calcularRuta(yo, destino);
    if (!mounted) return;
    setState(() {
      _calculando = false;
      if (r != null) {
        _ruta = r;
        _pasoIdx = r.pasos.length > 1 ? 1 : 0;
        _pasosDichos.clear();
        _restante = r.metros;
        _seguir = true;
      }
    });
    if (r == null) {
      _aviso('No se pudo calcular la ruta. Revisa tu conexión.');
      return;
    }
    if (!recalculo && _mapListo) {
      _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(r.puntos), padding: const EdgeInsets.all(70)));
    }
    if (aj.vozNavegacion) {
      Voz.instancia.decir(recalculo
          ? 'Recalculando ruta'
          : 'Ruta lista. ${_minutos(r.segundos)} minutos. ${r.pasos.first.texto}');
    }
  }

  void _avanzarRuta(LatLng yo) {
    final ruta = _ruta;
    if (ruta == null || _calculando) return;
    final aj = context.read<AjustesStore>();

    var mejor = 0;
    var dmin = double.infinity;
    for (var i = 0; i < ruta.puntos.length; i++) {
      final d = _dist(yo, ruta.puntos[i]);
      if (d < dmin) {
        dmin = d;
        mejor = i;
      }
    }
    if (dmin > 80 && _destino != null) {
      _trazar(_destino!, recalculo: true); // te saliste de la ruta
      return;
    }
    var rest = 0.0;
    for (var i = mejor; i < ruta.puntos.length - 1; i++) {
      rest += _dist(ruta.puntos[i], ruta.puntos[i + 1]);
    }
    while (_pasoIdx < ruta.pasos.length - 1 && _dist(yo, ruta.pasos[_pasoIdx].punto) < 25) {
      _pasoIdx++;
    }
    final paso = ruta.pasos[_pasoIdx];
    final dp = _dist(yo, paso.punto);
    final esUltimo = _pasoIdx == ruta.pasos.length - 1;

    if (esUltimo && dp < 30) {
      if (aj.vozNavegacion) Voz.instancia.decir('Llegaste a tu destino');
      _cancelarRuta();
      return;
    }
    if (aj.vozNavegacion && dp < 150 && _pasosDichos.add(_pasoIdx)) {
      Voz.instancia.decir('En ${(dp / 10).round() * 10} metros, ${paso.texto}');
    }
    setState(() => _restante = rest);
  }

  void _cancelarRuta() => setState(() {
        _ruta = null;
        _destino = null;
      });

  int _minutos(double s) => max(1, (s / 60).round());

  String _horaLlegada(double segundos) {
    final t = DateTime.now().add(Duration(seconds: segundos.round()));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
  }

  // ---------------------------------------------------------------- acciones

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  LatLng get _aqui => _pos ?? (_mapListo ? _map.camera.center : _bogota);

  Future<void> _reportar() async {
    final r = await Navigator.of(context).push<Reporte>(
        MaterialPageRoute(builder: (_) => NuevoReporteScreen(posicion: _aqui)));
    if (r != null) _publicar(r);
  }

  Future<void> _audioRapido() async {
    final g = await Navigator.of(context).push<Grabacion>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const GrabarScreen()));
    if (g == null || !mounted) return;
    final aj = context.read<AjustesStore>();
    final p = _aqui;
    _aviso('Enviando audio…');
    final dir = await direccionDe(p);
    _publicar(Reporte(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      categoria: Categoria.audio,
      direccion: dir,
      lat: p.latitude,
      lng: p.longitude,
      fecha: DateTime.now(),
      audioPath: g.path,
      audioSegundos: g.segundos,
      autor: aj.nombre,
      avatar: aj.avatar,
    ));
  }

  void _publicar(Reporte r) {
    _alertados.add(r.id); // no te alertes de tu propio reporte
    _store.agregar(r);
    _aviso('¡Reporte enviado! Gracias por cuidar la vía.');
  }

  Future<void> _elegirDestino(LatLng p) async {
    final c = context.rs;
    final ir = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: c.borde, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.place_rounded, color: c.accion, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<String>(
                  future: direccionDe(p),
                  builder: (_, s) => Text(s.data ?? 'Buscando dirección…',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            BotonPrincipal(
                texto: 'Ir aquí',
                icono: Icons.navigation_rounded,
                onTap: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    );
    if (ir == true) _trazar(p);
  }

  Future<void> _buscar() async {
    final destino = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuscarSheet(cerca: _pos),
    );
    if (destino != null) _trazar(destino);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    final aj = context.watch<AjustesStore>();
    final reportes = context.watch<ReportesStore>().items;
    final ruta = _ruta;

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pos ?? _bogota,
            initialZoom: 15,
            maxZoom: 19,
            backgroundColor: c.oscuro ? const Color(0xFF12161C) : const Color(0xFFEEF1F4),
            onMapReady: () {
              _mapListo = true;
              _onStore();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _seguir) setState(() => _seguir = false);
            },
            onLongPress: (_, p) => _elegirDestino(p),
          ),
          children: [
            // Mapas de OpenStreetMap: gratis y sin API key.
            // En tema oscuro se invierten los colores del mapa.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rovant.rovant',
              maxNativeZoom: 19,
              tileBuilder: c.oscuro ? darkModeTileBuilder : null,
            ),
            if (ruta != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: ruta.puntos,
                  strokeWidth: 7,
                  color: c.mapaRuta,
                  borderStrokeWidth: 2,
                  borderColor: Colors.black26,
                ),
              ]),
            MarkerLayer(markers: [
              for (final r in reportes)
                Marker(
                  point: LatLng(r.lat, r.lng),
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DetalleReporteScreen(reporte: r))),
                    child: IconoCategoria(r.categoria, tam: 40, borde: true),
                  ),
                ),
              if (_destino != null)
                Marker(
                  point: _destino!,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.flag_rounded, color: c.accion, size: 40),
                ),
              if (_pos != null)
                Marker(
                  point: _pos!,
                  width: 76,
                  height: 76,
                  child: _MiMarcador(avatar: aj.avatar, rumbo: _rumbo),
                ),
            ]),
          ],
        ),

        // ---- Barra superior: buscador o instrucción de giro
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              if (ruta != null)
                _BannerGiro(
                  paso: ruta.pasos[_pasoIdx],
                  metros: _pos == null ? 0 : _dist(_pos!, ruta.pasos[_pasoIdx].punto),
                )
              else
                _Buscador(avatar: aj.avatar, onTap: _buscar, cargando: _calculando),
              if (_alerta != null) ...[
                const SizedBox(height: 10),
                _TarjetaAlerta(
                  reporte: _alerta!,
                  metros: _alertaDist,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DetalleReporteScreen(reporte: _alerta!))),
                  onCerrar: () => setState(() => _alerta = null),
                ),
              ],
            ]),
          ),
        ),

        // ---- Botones laterales
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + (_alerta != null ? 190 : 100),
          child: Column(children: [
            BotonMapa(
              icono: aj.audioAuto ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              onTap: () {
                aj.setAudioAuto(!aj.audioAuto);
                if (!aj.audioAuto) Voz.instancia.callar();
                _aviso(aj.audioAuto ? 'Alertas con audio activadas' : 'Alertas silenciadas');
              },
            ),
            const SizedBox(height: 12),
            BotonMapa(
                icono: Icons.warning_rounded,
                color: Colors.white,
                fondo: Categoria.accidente.color,
                onTap: _reportar),
            const SizedBox(height: 12),
            BotonMapa(
                icono: Icons.mic_rounded,
                color: Colors.white,
                fondo: Categoria.audio.color,
                onTap: _audioRapido),
            const SizedBox(height: 12),
            BotonMapa(
              icono: _seguir ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: _seguir ? c.accion : null,
              onTap: () {
                setState(() => _seguir = true);
                if (_pos != null) _map.move(_pos!, 17);
              },
            ),
          ]),
        ),

        // ---- Velocímetro
        Positioned(left: 16, bottom: 118, child: _Velocimetro(_velocidad)),

        Positioned(
          right: 12,
          bottom: 104,
          child: Text('© OpenStreetMap',
              style: TextStyle(fontSize: 9, color: c.texto3)),
        ),

        // ---- Panel inferior
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.superficie,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RS.r20)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
            ),
            child: ruta != null
                ? Row(children: [
                    BotonMapa(icono: Icons.close_rounded, onTap: _cancelarRuta),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                            '${_minutos(ruta.metros == 0 ? 0 : ruta.segundos * _restante / ruta.metros)} min',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        Text(
                            '${distanciaTexto(_restante)} · ${_horaLlegada(ruta.metros == 0 ? 0 : ruta.segundos * _restante / ruta.metros)}',
                            style: TextStyle(color: c.texto2, fontSize: 13)),
                      ]),
                    ),
                    BotonMapa(icono: Icons.mic_rounded, onTap: _audioRapido),
                  ])
                : Row(children: [
                    Expanded(
                      child: BotonPrincipal(
                          texto: 'Reportar', icono: Icons.campaign_rounded, onTap: _reportar),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BotonSecundario(
                          texto: 'Grabar audio', icono: Icons.mic_rounded, onTap: _audioRapido),
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _MiMarcador extends StatelessWidget {
  const _MiMarcador({required this.avatar, required this.rumbo});
  final String avatar;
  final double rumbo;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: c.accion.withValues(alpha: 0.18)),
      ),
      Transform.rotate(
        angle: rumbo * pi / 180,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Align(
            alignment: Alignment.topCenter,
            child: Icon(Icons.navigation_rounded, color: c.accion, size: 20),
          ),
        ),
      ),
      Avatar(avatar, tam: 46, anillo: c.accion),
    ]);
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.avatar, required this.onTap, required this.cargando});
  final String avatar;
  final VoidCallback onTap;
  final bool cargando;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: c.superficie,
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
          child: Row(children: [
            Avatar(avatar, tam: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Text(cargando ? 'Calculando ruta…' : '¿A dónde vas?',
                  style: TextStyle(fontSize: 16, color: c.texto2, fontWeight: FontWeight.w500)),
            ),
            cargando
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.search_rounded, color: c.texto2),
          ]),
        ),
      ),
    );
  }
}

class _BannerGiro extends StatelessWidget {
  const _BannerGiro({required this.paso, required this.metros});
  final Paso paso;
  final double metros;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: c.banner,
        borderRadius: BorderRadius.circular(RS.r20),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
      ),
      child: Row(children: [
        Icon(paso.icono, color: Colors.white, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(distanciaTexto(metros),
                style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            Text(paso.calle.isNotEmpty ? paso.calle : paso.texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.oscuro ? RS.dorado : const Color(0xFF8CC2FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta(
      {required this.reporte, required this.metros, required this.onTap, required this.onCerrar});
  final Reporte reporte;
  final double metros;
  final VoidCallback onTap, onCerrar;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: c.superficie,
      elevation: 6,
      borderRadius: BorderRadius.circular(RS.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(RS.r14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RS.r14),
            border: Border(left: BorderSide(color: reporte.categoria.color, width: 5)),
          ),
          child: Row(children: [
            IconoCategoria(reporte.categoria, tam: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${reporte.categoria.nombre} · ${distanciaTexto(metros)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(reporte.direccion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.texto2, fontSize: 13)),
              ]),
            ),
            if (reporte.tieneAudio)
              IconButton(
                icon: Icon(Icons.play_circle_fill_rounded, color: c.accion, size: 34),
                onPressed: () => Voz.instancia.alerta('', reporte.audioPath),
              ),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: onCerrar),
          ]),
        ),
      ),
    );
  }
}

class _Velocimetro extends StatelessWidget {
  const _Velocimetro(this.kmh);
  final double kmh;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: c.superficie,
        shape: BoxShape.circle,
        border: Border.all(color: RS.dorado, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(kmh.round().toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1)),
        Text('km/h', style: TextStyle(fontSize: 11, color: c.texto2)),
      ]),
    );
  }
}

class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({required this.texto, required this.icono, required this.onTap});
  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Material(
      color: c.elevada,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icono, color: c.accion),
            const SizedBox(width: 8),
            Text(texto, style: TextStyle(color: c.texto, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _BuscarSheet extends StatefulWidget {
  const _BuscarSheet({this.cerca});
  final LatLng? cerca;
  @override
  State<_BuscarSheet> createState() => _BuscarSheetState();
}

class _BuscarSheetState extends State<_BuscarSheet> {
  List<Lugar> _res = [];
  bool _buscando = false;

  Future<void> _go(String q) async {
    if (q.trim().length < 3) return;
    setState(() => _buscando = true);
    final r = await buscarLugares(q.trim(), widget.cerca);
    if (mounted) {
      setState(() {
        _res = r;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _go,
                decoration: InputDecoration(
                  hintText: 'Busca una dirección o lugar',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: c.elevada,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_buscando) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _res.isEmpty && !_buscando
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            'Escribe y presiona buscar.\nTambién puedes mantener presionado el mapa para elegir un destino.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.texto2)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _res.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: c.borde),
                      itemBuilder: (_, i) => ListTile(
                        leading: Icon(Icons.place_rounded, color: c.accion),
                        title: Text(_res[i].nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_res[i].detalle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.texto2)),
                        onTap: () => Navigator.pop(context, _res[i].punto),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
