import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'movimiento.dart';
import 'tipografia.dart';
import 'tokens.dart';

/// Tema claro sobre los dos colores de la marca. Un solo lugar decide cómo se
/// ve todo.
class AppTheme {
  const AppTheme._();

  static ThemeData claro() {
    const esquema = ColorScheme.light(
      primary: Tono.vino,
      onPrimary: Tono.textoInverso,
      primaryContainer: Tono.vinoSuave,
      onPrimaryContainer: Tono.vinoTexto,
      secondary: Tono.oro,
      onSecondary: Colors.white,
      secondaryContainer: Tono.oroSuave,
      onSecondaryContainer: Tono.oroTexto,
      surface: Tono.fondo,
      onSurface: Tono.texto,
      error: Tono.vino,
      onError: Colors.white,
      outline: Tono.linea,
      outlineVariant: Tono.lineaFuerte,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      // Una sola familia para toda la app, incluidos los widgets que no
      // pasan por `Tipo`: un menú de Material con la fuente del sistema al
      // lado de una pantalla con Archivo se nota enseguida.
      fontFamily: familia,
      scaffoldBackgroundColor: Tono.fondo2,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _TransicionDeslizar(),
          TargetPlatform.iOS: _TransicionDeslizar(),
          TargetPlatform.windows: _TransicionDeslizar(),
          TargetPlatform.macOS: _TransicionDeslizar(),
          TargetPlatform.linux: _TransicionDeslizar(),
        },
      ),
      textTheme: _texto(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Tono.fondo,
        foregroundColor: Tono.texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: Tipo.encabezado,
      ),
      // Sin borde: la separación la da el color de la superficie y el aire.
      cardTheme: const CardThemeData(
        color: Tono.fondo,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Redondeo.brNormal),
      ),
      dividerTheme: const DividerThemeData(
        color: Tono.linea,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Blanco con una línea fina, y **no** el hueso del fondo: cuando el
        // relleno del campo era el mismo color que la página, los formularios
        // se veían como una lista de etiquetas sueltas y no había forma de
        // saber dónde se escribía. El borde es lo que dice "acá va tu texto".
        fillColor: Tono.fondo,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Espacio.lg,
          vertical: Espacio.lg,
        ),
        hintStyle: Tipo.cuerpo.copyWith(color: Tono.texto3),
        // La etiqueta flota adentro del campo en vez de ir arriba en
        // mayúsculas: así el nombre del dato viaja con el dato y desaparece
        // una fila de texto gris por cada campo del formulario.
        labelStyle: Tipo.cuerpo.copyWith(color: Tono.texto2),
        floatingLabelStyle: Tipo.nota.copyWith(color: Tono.vinoTexto),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: _borde(Tono.lineaFuerte),
        enabledBorder: _borde(Tono.lineaFuerte),
        focusedBorder: _borde(Tono.vino, grosor: 2),
        errorBorder: _borde(Tono.vino, grosor: 1.5),
        focusedErrorBorder: _borde(Tono.vino, grosor: 2),
        errorStyle: const TextStyle(
          color: Tono.vino,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tono.vino,
          foregroundColor: Tono.textoInverso,
          // Un botón apagado tiene que **leerse**: blanco sobre gris claro
          // daba 1.8:1 y se veía como un botón a medio dibujar. Esto da 4.7:1.
          disabledBackgroundColor: Tono.apagadoFondo,
          disabledForegroundColor: Tono.apagadoTexto,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xl),
          shape: const RoundedRectangleBorder(borderRadius: Redondeo.brChico),
          textStyle: Tipo.boton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Tono.texto,
          backgroundColor: Tono.fondo,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xl),
          side: const BorderSide(color: Tono.lineaFuerte),
          shape: const RoundedRectangleBorder(borderRadius: Redondeo.brChico),
          textStyle: Tipo.boton.copyWith(color: Tono.texto),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Tono.vinoTexto,
          minimumSize: const Size(0, kAreaTactil),
          textStyle: Tipo.boton.copyWith(fontSize: 15, color: Tono.vinoTexto),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Tono.fondo,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: Espacio.md,
          vertical: Espacio.sm,
        ),
        labelStyle: Tipo.nota.copyWith(fontSize: 13.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Tono.texto,
        contentTextStyle: Tipo.cuerpo.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Redondeo.brChico),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Tono.fondo,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Redondeo.grande)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Tono.fondo,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Redondeo.brNormal),
        titleTextStyle: Tipo.titulo2,
        contentTextStyle: Tipo.cuerpo.copyWith(color: Tono.texto2),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: Espacio.md,
        iconColor: Tono.texto2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Tono.vino,
        linearTrackColor: Tono.linea,
      ),
    );
  }

  static OutlineInputBorder _borde(Color color, {double grosor = 1.5}) =>
      OutlineInputBorder(
        borderRadius: Redondeo.brChico,
        borderSide: BorderSide(color: color, width: grosor),
      );

  static TextTheme _texto(TextTheme base) => base.copyWith(
        displaySmall: Tipo.display,
        headlineMedium: Tipo.titulo1,
        headlineSmall: Tipo.titulo2,
        titleLarge: Tipo.titulo2,
        titleMedium: Tipo.encabezado,
        bodyLarge: Tipo.cuerpo,
        bodyMedium: Tipo.secundario,
        bodySmall: Tipo.nota,
        labelLarge: Tipo.boton.copyWith(color: Tono.texto),
        labelSmall: Tipo.etiqueta,
      );
}

/// Entrada de pantalla: desliza poco y aparece, con el resorte sin rebote.
/// Solo posición y opacidad — nada de blur animado.
class _TransicionDeslizar extends PageTransitionsBuilder {
  const _TransicionDeslizar();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (sinAnimaciones(context)) return child;

    final curva = CurvedAnimation(
      parent: animation,
      curve: Movimiento.muelle,
      reverseCurve: Movimiento.salida,
    );

    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }
}
