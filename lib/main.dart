import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/stores.dart';
import 'screens/home_shell.dart';
import 'screens/inicio_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final ajustes = AjustesStore();
  await ajustes.load();
  final reportes = ReportesStore();
  await reportes.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ajustes),
      ChangeNotifierProvider.value(value: reportes),
    ],
    child: const RovantApp(),
  ));
}

class RovantApp extends StatefulWidget {
  const RovantApp({super.key});
  @override
  State<RovantApp> createState() => _RovantAppState();
}

class _RovantAppState extends State<RovantApp> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Revisa cada minuto si ya son las 6 a. m. o las 6 p. m. para cambiar el tema.
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aj = context.watch<AjustesStore>();
    return MaterialApp(
      title: 'Rovant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: aj.temaEfectivo,
      home: aj.onboardingVisto ? const HomeShell() : const InicioScreen(),
    );
  }
}
