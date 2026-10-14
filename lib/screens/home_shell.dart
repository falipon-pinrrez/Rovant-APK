import 'package:flutter/material.dart';

import '../theme.dart';
import 'config_screen.dart';
import 'mapa_screen.dart';
import 'reportes_screen.dart';

/// Pestaña activa (0 = mapa, 1 = reportes, 2 = perfil). Global para que
/// "Ver en mapa" pueda saltar al mapa desde cualquier pantalla.
final pestana = ValueNotifier<int>(0);

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rs;
    return ValueListenableBuilder<int>(
      valueListenable: pestana,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: const [
          MapaScreen(),
          ReportesScreen(),
          ConfigScreen(),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: c.superficie,
            border: Border(top: BorderSide(color: c.borde)),
          ),
          child: BottomNavigationBar(
            currentIndex: i,
            onTap: (n) => pestana.value = n,
            backgroundColor: c.superficie,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: c.accion,
            unselectedItemColor: c.texto2,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Reportes'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}
