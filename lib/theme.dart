import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de marca (iguales en ambos temas) – Guía de color (marca Rovant).
class RS {
  static const dorado = Color(0xFFE9B44C);
  static const doradoClaro = Color(0xFFF6CE72);
  static const doradoOscuro = Color(0xFFC98E2B);
  static const azulNoche = Color(0xFF1B2433);
  static const gradDorado = LinearGradient(colors: [doradoClaro, doradoOscuro]);

  // Radios y espaciado
  static const r8 = 8.0, r14 = 14.0, r20 = 20.0;
}

/// Tokens que cambian entre tema oscuro y claro.
@immutable
class RSColors extends ThemeExtension<RSColors> {
  const RSColors({
    required this.base,
    required this.superficie,
    required this.elevada,
    required this.borde,
    required this.texto,
    required this.texto2,
    required this.texto3,
    required this.accion,
    required this.accionTexto,
    required this.suave,
    required this.banner,
    required this.mapaRuta,
    required this.oscuro,
  });

  final Color base, superficie, elevada, borde, texto, texto2, texto3;
  final Color accion, accionTexto, suave, banner, mapaRuta;
  final bool oscuro;

  static const oscuroTokens = RSColors(
    base: Color(0xFF0D1015),
    superficie: Color(0xFF171B21),
    elevada: Color(0xFF20252D),
    borde: Color(0xFF2B313A),
    texto: Color(0xFFFFFFFF),
    texto2: Color(0xFFA3AAB5),
    texto3: Color(0xFF6E7581),
    accion: Color(0xFFE9B44C),
    accionTexto: Color(0xFF1A1406),
    suave: Color(0xFF3A2F18),
    banner: Color(0xFF11151B),
    mapaRuta: Color(0xFFF5B83D),
    oscuro: true,
  );

  static const claroTokens = RSColors(
    base: Color(0xFFF4F6F9),
    superficie: Color(0xFFFFFFFF),
    elevada: Color(0xFFEEF1F5),
    borde: Color(0xFFE2E6EC),
    texto: Color(0xFF111827),
    texto2: Color(0xFF6B7280),
    texto3: Color(0xFF9CA3AF),
    accion: Color(0xFF1E7BF2),
    accionTexto: Color(0xFFFFFFFF),
    suave: Color(0xFFDCEBFE),
    banner: Color(0xFF2B3442),
    mapaRuta: Color(0xFF2F8CFF),
    oscuro: false,
  );

  /// Botón principal: degradado dorado en oscuro, azul sólido en claro.
  Gradient get gradPrincipal => oscuro
      ? RS.gradDorado
      : const LinearGradient(colors: [Color(0xFF3A8DF5), Color(0xFF1E7BF2)]);

  @override
  RSColors copyWith() => this;

  @override
  RSColors lerp(ThemeExtension<RSColors>? other, double t) =>
      (other is RSColors && t >= 0.5) ? other : this;
}

extension RSContext on BuildContext {
  RSColors get rs => Theme.of(this).extension<RSColors>()!;
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? RSColors.oscuroTokens : RSColors.claroTokens;
  final base = ThemeData(brightness: b, useMaterial3: true);
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: c.texto, displayColor: c.texto);
  return base.copyWith(
    scaffoldBackgroundColor: c.base,
    colorScheme: ColorScheme.fromSeed(seedColor: c.accion, brightness: b).copyWith(
      primary: c.accion,
      onPrimary: c.accionTexto,
      surface: c.superficie,
      onSurface: c.texto,
    ),
    textTheme: text,
    dividerColor: c.borde,
    appBarTheme: AppBarTheme(
      backgroundColor: c.base,
      foregroundColor: c.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle:
          GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: c.texto),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.texto3),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accion : c.elevada),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.elevada,
      contentTextStyle: GoogleFonts.inter(color: c.texto, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.superficie),
    dialogTheme: DialogThemeData(backgroundColor: c.superficie),
    extensions: [c],
  );
}
