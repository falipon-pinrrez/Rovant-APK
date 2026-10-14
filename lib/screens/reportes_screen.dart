import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../models/reporte.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'detalle_reporte_screen.dart';

/// Lista de reportes con filtros por categoría.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  Categoria? _filtro;

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    final todos = context.watch<ReportesStore>().items;
    final lista = _filtro == null ? todos : todos.where((r) => r.categoria == _filtro).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _Chip('Todos', _filtro == null, () => setState(() => _filtro = null)),
              for (final cat in Categoria.values)
                _Chip(cat.corto, _filtro == cat, () => setState(() => _filtro = cat)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_rounded, size: 54, color: c.texto3),
                    const SizedBox(height: 10),
                    Text('No hay reportes por aquí', style: TextStyle(color: c.texto2)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = lista[i];
                    return Tarjeta(
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DetalleReporteScreen(reporte: r))),
                      child: Row(children: [
                        IconoCategoria(r.categoria),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(
                                child: Text(r.categoria.nombre,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                              if (r.tieneAudio) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.graphic_eq_rounded, size: 16, color: c.accion),
                              ],
                              if (r.tieneFoto) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.photo_rounded, size: 16, color: c.accion),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text('${r.direccion} · ${hace(r.fecha)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.texto2, fontSize: 12)),
                          ]),
                        ),
                        if (r.avatar != null) ...[
                          const SizedBox(width: 8),
                          Avatar(r.avatar, tam: 30),
                        ],
                        Icon(Icons.chevron_right_rounded, color: c.texto3),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, this.activo, this.onTap);
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: activo ? c.accion : c.elevada,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(texto,
                style: TextStyle(
                  color: activo ? c.accionTexto : c.texto,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                )),
          ),
        ),
      ),
    );
  }
}
