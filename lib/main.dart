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

class RovantApp extends StatelessWidget {
  const RovantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final aj = context.watch<AjustesStore>();
    return MaterialApp(
      title: 'Rovant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: aj.themeMode,
      home: aj.onboardingVisto ? const HomeShell() : const InicioScreen(),
    );
  }
}
