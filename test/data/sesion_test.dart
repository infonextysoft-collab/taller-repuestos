import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/auth_repository_sqlite.dart';

/// La sesión dura el día, no para siempre.
void main() {
  late AppDatabase base;
  late AuthRepositorySqlite auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    base = await AppDatabase.enMemoria();
    auth = AuthRepositorySqlite(base);
  });

  tearDown(() => base.cerrar());

  test('sin haber entrado nunca, no hay sesión', () async {
    expect(await auth.haySesion(), isFalse);
  });

  test('entrar deja la sesión abierta el mismo día', () async {
    await auth.abrirSesion();
    expect(await auth.haySesion(), isTrue);
  });

  test('una sesión de ayer ya no vale', () async {
    SharedPreferences.setMockInitialValues({
      'sesion_dia': sumarDias(hoyISO(), -1),
    });

    expect(await auth.haySesion(), isFalse);
  });

  test('cerrar sesión la borra', () async {
    await auth.abrirSesion();
    await auth.cerrarSesion();
    expect(await auth.haySesion(), isFalse);
  });

  test('la sesión vieja, que era un booleano, no rompe ni vale', () async {
    // Las versiones anteriores guardaban `sesion_abierta: true`. Leer eso como
    // texto reventaría, así que la clave es otra y la vieja se descarta.
    SharedPreferences.setMockInitialValues({'sesion_abierta': true});

    expect(await auth.haySesion(), isFalse);

    await auth.abrirSesion();
    expect(await auth.haySesion(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sesion_abierta'), isFalse);
  });
}
