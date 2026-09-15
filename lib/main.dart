import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/pantalla_arranque_fallido.dart';
import 'app/providers.dart';
import 'data/cuenta/cuenta_firebase.dart';
import 'data/local/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // La app se usa con una mano, parada: nunca de costado.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // La cuenta de correo arranca a la par de la base, no después: así el
    // arranque tarda lo que la más lenta de las dos, no la suma. Nunca falla
    // —sin Firebase la app sigue igual, solo sin recuperación por correo— y
    // por eso puede quedar corriendo mientras se abre la base.
    final cuenta = CuentaFirebase.iniciar();

    // La base se abre antes de dibujar nada: es local, tarda unos
    // milisegundos, y así ninguna pantalla tiene que preguntarse si ya existe.
    final base = await AppDatabase.abrir();

    runApp(
      ProviderScope(
        overrides: [
          baseDatosProvider.overrideWithValue(base),
          cuentaRemotaProvider.overrideWithValue(await cuenta),
        ],
        child: const AppMs(),
      ),
    );
  } catch (error, traza) {
    // Si el arranque falla, se dice. Una pantalla en blanco obliga a abrir la
    // consola para enterarse de qué pasó.
    runApp(PantallaArranqueFallido(error: error, traza: traza));
  }
}
