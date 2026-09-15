import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_repuestos/core/utils/clave_segura.dart';
import 'package:taller_repuestos/data/cuenta/cuenta_remota.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/auth_repository_sqlite.dart';
import 'package:taller_repuestos/domain/repositories/auth_repository.dart';

import '../falsos/cuenta_falsa.dart';

/// El acceso, con y sin cuenta de correo.
///
/// La regla que atraviesa todo: **la huella del teléfono decide quién entra**.
/// La cuenta de correo recupera la contraseña, pero nunca puede dejar afuera a
/// quien tiene la contraseña con la que entró por última vez —eso ya pasaría
/// igual sin señal—.
void main() {
  late AppDatabase base;
  late CuentaFalsa nube;
  late AuthRepositorySqlite auth;

  /// El tiempo con la app abierta, que es lo único que descuenta el freno.
  late Duration pasado;

  const correo = 'wilmer@correo.pe';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    base = await AppDatabase.enMemoria();
    nube = CuentaFalsa();
    pasado = Duration.zero;
    auth = AuthRepositorySqlite(base, nube, vueltas: 500, reloj: () => pasado);
  });

  tearDown(() => base.cerrar());

  Future<Map<String, Object?>> fila() async =>
      (await base.db.query('auth', where: 'id = 1')).single;

  /// Deja el teléfono con una contraseña con huella, sin pasar por la pantalla.
  Future<void> ponerClave(String clave) async {
    final huella = HuellaClave.de(clave, vueltas: 500);
    await base.db.update(
      'auth',
      {
        'claveHuella': huella.huella,
        'claveSal': huella.sal,
        'claveVueltas': huella.vueltas,
      },
      where: 'id = 1',
    );
  }

  /// Teléfono con contraseña propia y el correo ya vinculado.
  Future<void> conCorreo({String clave = 'Taller2026'}) async {
    await ponerClave(clave);
    final r = await auth.vincularCorreo(correo: correo, claveApp: clave);
    expect(r.correcto, isTrue, reason: r.error);
    nube.llamadas.clear();
  }

  group('sin correo, como siempre', () {
    test('entra con la de fábrica, sin distinguir mayúsculas en el usuario',
        () async {
      final r = await auth.entrar(usuario: 'samuel', clave: claveInicial);
      expect(r.correcto, isTrue);
    });

    test('usuario o contraseña equivocados no entran', () async {
      expect(
        (await auth.entrar(usuario: 'Samuel', clave: 'admin123')).motivo,
        MotivoAuth.claveIncorrecta,
      );
      expect(
        (await auth.entrar(usuario: 'Otro', clave: claveInicial)).correcto,
        isFalse,
      );
    });

    test('nunca llama a la nube', () async {
      await auth.entrar(usuario: 'Samuel', clave: claveInicial);
      expect(nube.llamadas, isEmpty);
    });

    test('cambiar la contraseña guarda la huella, nunca el texto', () async {
      final r = await auth.cambiarClave(claveInicial, 'Taller2026');
      expect(r.correcto, isTrue);

      final guardada = await fila();
      expect(guardada['clave'], '');
      expect(guardada['claveHuella'], isNot(contains('Taller2026')));

      expect(
        (await auth.entrar(usuario: 'Samuel', clave: 'Taller2026')).correcto,
        isTrue,
      );
      expect(
        (await auth.entrar(usuario: 'Samuel', clave: claveInicial)).correcto,
        isFalse,
      );
    });

    test('la nueva necesita 6 caracteres y la actual tiene que ser la buena',
        () async {
      expect(
        (await auth.cambiarClave(claveInicial, '12345')).motivo,
        MotivoAuth.claveCorta,
      );
      expect(
        (await auth.cambiarClave('otra-cosa', 'Taller2026')).motivo,
        MotivoAuth.claveIncorrecta,
      );
    });

    test('"cambiar" la de fábrica por ella misma no la saca de fábrica',
        () async {
      // Era la puerta para vincular una cuenta con la contraseña del README:
      // quedaba con huella y dejaba de reconocerse como de fábrica.
      final r = await auth.cambiarClave(claveInicial, claveInicial);

      expect(r.motivo, MotivoAuth.claveDeFabrica);
      expect((await auth.estado()).claveDeFabrica, isTrue);
      expect((await fila())['claveHuella'], isNull);
    });

    test('tampoco se puede volver a la de fábrica', () async {
      await auth.cambiarClave(claveInicial, 'Taller2026');

      final r = await auth.cambiarClave('Taller2026', claveInicial);
      expect(r.motivo, MotivoAuth.claveDeFabrica);
      expect(
        (await auth.entrar(usuario: 'Samuel', clave: 'Taller2026')).correcto,
        isTrue,
      );
    });

    test('el estado dice si sigue la de fábrica y si hay nube', () async {
      var estado = await auth.estado();
      expect(estado.claveDeFabrica, isTrue);
      expect(estado.conCorreo, isFalse);
      expect(estado.nubeDisponible, isTrue);

      await auth.cambiarClave(claveInicial, 'Taller2026');
      estado = await auth.estado();
      expect(estado.claveDeFabrica, isFalse);

      final sinNube = AuthRepositorySqlite(
        base,
        const CuentaNoDisponible(),
        vueltas: 500,
      );
      expect((await sinNube.estado()).nubeDisponible, isFalse);
    });
  });

  group('freno de intentos', () {
    Future<void> equivocarse(int veces) async {
      for (var i = 0; i < veces; i++) {
        await auth.entrar(usuario: 'Samuel', clave: 'mal-$i');
      }
    }

    Future<ResultadoAuth> probarLaBuena() =>
        auth.entrar(usuario: 'Samuel', clave: claveInicial);

    test('los primeros cinco errores no cuestan nada', () async {
      await equivocarse(5);
      expect((await probarLaBuena()).correcto, isTrue);
    });

    test('desde el sexto error hay que esperar, aunque la clave sea buena',
        () async {
      await equivocarse(6);

      final r = await probarLaBuena();
      expect(r.motivo, MotivoAuth.esperar);
      expect(r.error, contains('30 segundos'));
    });

    test('pasada la espera se puede probar, y acertar limpia la cuenta',
        () async {
      await equivocarse(6);
      pasado += const Duration(seconds: 31);

      expect((await probarLaBuena()).correcto, isTrue);

      // Limpio: cinco errores más no hacen esperar.
      await equivocarse(5);
      expect((await probarLaBuena()).correcto, isTrue);
    });

    test('la espera se duplica con cada error de más, hasta cinco minutos',
        () async {
      await equivocarse(6);
      expect((await probarLaBuena()).error, contains('30 segundos'));

      for (final esperado in [
        '1 minuto',
        '2 minutos',
        '4 minutos',
        '5 minutos',
        '5 minutos',
      ]) {
        // Pasa lo suficiente para cumplir cualquier espera, y otro error.
        pasado += const Duration(minutes: 6);
        await equivocarse(1);

        final r = await probarLaBuena();
        expect(r.motivo, MotivoAuth.esperar);
        expect(r.error, contains(esperado));
      }
    });

    test('cerrar y abrir la app no termina la espera', () async {
      await equivocarse(6);

      // Otra instancia, con su reloj en cero: como la app recién abierta.
      final reabierta = AuthRepositorySqlite(
        base,
        nube,
        vueltas: 500,
        reloj: () => Duration.zero,
      );
      expect(
        (await reabierta.entrar(usuario: 'Samuel', clave: claveInicial)).motivo,
        MotivoAuth.esperar,
      );
    });

    test('la espera nunca pasa de cinco minutos, diga lo que diga lo guardado',
        () async {
      // Con la hora del teléfono, un reloj que volvía atrás dejaba esperas de
      // horas. Aunque algo raro quede guardado, el tope manda.
      SharedPreferences.setMockInitialValues({
        'auth_espera_ms': const Duration(days: 1).inMilliseconds,
      });

      final r = await probarLaBuena();
      expect(r.motivo, MotivoAuth.esperar);
      expect(r.error, contains('5 minutos'));

      pasado += const Duration(minutes: 5, seconds: 1);
      expect((await probarLaBuena()).correcto, isTrue);
    });

    test('con señal, los rechazos de la cuenta también cuentan', () async {
      await conCorreo();

      for (var i = 0; i < 6; i++) {
        await auth.entrar(clave: 'mal-$i');
      }
      expect(
        (await auth.entrar(clave: 'Taller2026')).motivo,
        MotivoAuth.esperar,
      );
    });

    test('sin señal, el modo avión no da intentos ilimitados', () async {
      await conCorreo();
      nube.forzar = FalloRemoto.sinConexion;

      for (var i = 0; i < 6; i++) {
        await auth.entrar(clave: 'mal-$i');
      }
      expect(
        (await auth.entrar(clave: 'Taller2026')).motivo,
        MotivoAuth.esperar,
      );
    });
  });

  group('vincular el correo', () {
    test('con la contraseña de fábrica no deja, y no toca la nube', () async {
      final r = await auth.vincularCorreo(
        correo: correo,
        claveApp: claveInicial,
      );

      expect(r.motivo, MotivoAuth.claveDeFabrica);
      expect(nube.llamadas, isEmpty);
      expect(nube.cuentas, isEmpty);
    });

    test('una huella de la de fábrica tampoco deja vincular', () async {
      // Así quedaba el teléfono antes del arreglo, si alguien "cambiaba" la de
      // fábrica por ella misma.
      await ponerClave(claveInicial);

      final r = await auth.vincularCorreo(
        correo: correo,
        claveApp: claveInicial,
      );
      expect(r.motivo, MotivoAuth.claveDeFabrica);
      expect(nube.llamadas, isEmpty);
    });

    test('una cuenta de correo con la de fábrica no se vincula', () async {
      await ponerClave('Taller2026');
      nube.cuentas[correo] = claveInicial;

      final r = await auth.vincularCorreo(
        correo: correo,
        claveApp: 'Taller2026',
        claveCuenta: claveInicial,
      );
      expect(r.motivo, MotivoAuth.claveDeFabrica);
      expect(nube.llamadas, isEmpty);
      expect((await auth.estado()).conCorreo, isFalse);
    });

    test('sin nube disponible no deja', () async {
      await ponerClave('Taller2026');
      nube.disponible = false;

      final r = await auth.vincularCorreo(correo: correo, claveApp: 'Taller2026');
      expect(r.motivo, MotivoAuth.noDisponible);
    });

    test('un correo mal escrito no llega a la nube', () async {
      await ponerClave('Taller2026');

      final r = await auth.vincularCorreo(
        correo: 'wilmer@correo',
        claveApp: 'Taller2026',
      );
      expect(r.motivo, MotivoAuth.correoInvalido);
      expect(nube.llamadas, isEmpty);
    });

    test('la contraseña de la app autoriza: equivocada, no toca la nube',
        () async {
      await ponerClave('Taller2026');

      final r = await auth.vincularCorreo(correo: correo, claveApp: 'otra');
      expect(r.motivo, MotivoAuth.claveIncorrecta);
      expect(nube.llamadas, isEmpty);
    });

    test('una contraseña corta pide cambiarla primero', () async {
      await ponerClave('12345');

      final r = await auth.vincularCorreo(correo: correo, claveApp: '12345');
      expect(r.motivo, MotivoAuth.claveCorta);
      expect(r.error, contains('Cámbiala primero'));
      expect(nube.llamadas, isEmpty);
    });

    test('correo nuevo: crea la cuenta con la de la app y pide confirmarlo',
        () async {
      await ponerClave('Taller2026');

      final r = await auth.vincularCorreo(
        correo: '  Wilmer@Correo.PE ',
        claveApp: 'Taller2026',
      );

      expect(r.correcto, isTrue);
      expect(nube.cuentas[correo], 'Taller2026');
      expect(nube.confirmaciones, 1);
      expect(r.aviso, contains('confirmar'));
      expect((await auth.estado()).correo, correo);
    });

    test('el correo ya tenía cuenta con la misma contraseña: se vincula',
        () async {
      await ponerClave('Taller2026');
      nube.cuentas[correo] = 'Taller2026';
      nube.correoVerificado = true;

      final r = await auth.vincularCorreo(correo: correo, claveApp: 'Taller2026');

      expect(r.correcto, isTrue);
      // Ya estaba confirmado: no se manda otro correo.
      expect(nube.confirmaciones, 0);
      expect((await auth.estado()).conCorreo, isTrue);
    });

    test('el correo tiene cuenta con otra contraseña: la pide y no vincula',
        () async {
      await ponerClave('Taller2026');
      nube.cuentas[correo] = 'Moto5566';

      final r = await auth.vincularCorreo(correo: correo, claveApp: 'Taller2026');

      expect(r.motivo, MotivoAuth.cuentaConOtraClave);
      expect((await auth.estado()).conCorreo, isFalse);
    });

    test('con la de la cuenta vincula, y queda una sola contraseña', () async {
      await ponerClave('Taller2026');
      nube.cuentas[correo] = 'Moto5566';

      final r = await auth.vincularCorreo(
        correo: correo,
        claveApp: 'Taller2026',
        claveCuenta: 'Moto5566',
      );
      expect(r.correcto, isTrue);

      // Sin señal se ve qué quedó guardado en el teléfono.
      nube.forzar = FalloRemoto.sinConexion;
      expect((await auth.entrar(clave: 'Moto5566')).correcto, isTrue);
      expect((await auth.entrar(clave: 'Taller2026')).correcto, isFalse);
    });

    test('la de la cuenta equivocada no vincula', () async {
      await ponerClave('Taller2026');
      nube.cuentas[correo] = 'Moto5566';

      final r = await auth.vincularCorreo(
        correo: correo,
        claveApp: 'Taller2026',
        claveCuenta: 'Moto0000',
      );
      expect(r.motivo, MotivoAuth.cuentaConOtraClave);
      expect((await auth.estado()).conCorreo, isFalse);
    });

    test('sin señal no vincula', () async {
      await ponerClave('Taller2026');
      nube.forzar = FalloRemoto.sinConexion;

      final r = await auth.vincularCorreo(correo: correo, claveApp: 'Taller2026');
      expect(r.motivo, MotivoAuth.sinConexion);
      expect((await auth.estado()).conCorreo, isFalse);
    });

    test('con un correo ya vinculado hay que desvincular antes', () async {
      await conCorreo();

      final r = await auth.vincularCorreo(
        correo: 'otro@correo.pe',
        claveApp: 'Taller2026',
      );
      expect(r.correcto, isFalse);
      expect((await auth.estado()).correo, correo);
    });
  });

  group('entrar con correo vinculado', () {
    setUp(conCorreo);

    test('con señal y la contraseña buena, entra sin pedir usuario', () async {
      final r = await auth.entrar(clave: 'Taller2026');
      expect(r.correcto, isTrue);
      expect(nube.llamadas, ['entrar:$correo']);
    });

    test('una contraseña cambiada con el enlace entra y queda en el teléfono',
        () async {
      // Se cambió desde el enlace del correo, en otra parte.
      nube.cuentas[correo] = 'Nueva2026';

      expect((await auth.entrar(clave: 'Nueva2026')).correcto, isTrue);

      // Desde ahí la nueva sirve sin señal, y la vieja ya no.
      nube.forzar = FalloRemoto.sinConexion;
      expect((await auth.entrar(clave: 'Nueva2026')).correcto, isTrue);
      expect((await auth.entrar(clave: 'Taller2026')).correcto, isFalse);
    });

    test('si la cuenta acepta la de fábrica, el teléfono la cuenta como tal',
        () async {
      nube.cuentas[correo] = claveInicial;

      expect((await auth.entrar(clave: claveInicial)).correcto, isTrue);
      expect((await auth.estado()).claveDeFabrica, isTrue);
    });

    test('con señal, una contraseña que no es de nadie no entra', () async {
      final r = await auth.entrar(clave: 'cualquiera');
      expect(r.motivo, MotivoAuth.claveIncorrecta);
    });

    test('la cuenta rechaza la última contraseña del teléfono: ofrece seguir '
        'sin la cuenta, y no deja afuera', () async {
      nube.cuentas[correo] = 'LaCambioOtro';

      final r = await auth.entrar(clave: 'Taller2026');
      expect(r.correcto, isFalse);
      expect(r.motivo, MotivoAuth.cuentaRechazaClave);

      final desvinculado = await auth.desvincularCorreo('Taller2026');
      expect(desvinculado.correcto, isTrue);
      expect((await auth.estado()).conCorreo, isFalse);
      expect(
        (await auth.entrar(usuario: 'Samuel', clave: 'Taller2026')).correcto,
        isTrue,
      );
    });

    test('una cuenta desactivada tampoco deja afuera', () async {
      nube.desactivadas.add(correo);

      final r = await auth.entrar(clave: 'Taller2026');
      expect(r.motivo, MotivoAuth.cuentaRechazaClave);
      expect(r.error, contains('desactivada'));
    });

    test('sin señal entra con la última contraseña, y con otra explica qué '
        'hacer', () async {
      nube.forzar = FalloRemoto.sinConexion;

      expect((await auth.entrar(clave: 'Taller2026')).correcto, isTrue);

      final r = await auth.entrar(clave: 'Nueva2026');
      expect(r.correcto, isFalse);
      expect(r.error, contains('conéctate'));
    });

    test('si Firebase frena por intentos, decide la huella', () async {
      nube.forzar = FalloRemoto.demasiadosIntentos;
      expect((await auth.entrar(clave: 'Taller2026')).correcto, isTrue);
    });

    test('en una instalación sin Firebase, decide la huella', () async {
      nube.disponible = false;
      expect((await auth.entrar(clave: 'Taller2026')).correcto, isTrue);
      expect(nube.llamadas, isEmpty);
    });
  });

  group('cambiar la contraseña con correo', () {
    setUp(conCorreo);

    test('con señal cambia en la cuenta y en el teléfono', () async {
      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.correcto, isTrue);
      expect(nube.cuentas[correo], 'Otra2026');

      nube.forzar = FalloRemoto.sinConexion;
      expect((await auth.entrar(clave: 'Otra2026')).correcto, isTrue);
    });

    test('sin señal no cambia nada', () async {
      nube.forzar = FalloRemoto.sinConexion;

      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.motivo, MotivoAuth.sinConexion);
      expect(nube.cuentas[correo], 'Taller2026');
      expect((await auth.entrar(clave: 'Taller2026')).correcto, isTrue);
    });

    test('la actual la valida la cuenta, aunque la huella esté vieja',
        () async {
      nube.cuentas[correo] = 'Nueva2026';

      final r = await auth.cambiarClave('Nueva2026', 'Otra2026');
      expect(r.correcto, isTrue);
    });

    test('si la cuenta rechaza la actual pero es la del teléfono, no dice que '
        'es incorrecta', () async {
      nube.cuentas[correo] = 'LaCambioOtro';

      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.motivo, MotivoAuth.cuentaRechazaClave);
      expect(r.error, contains('desvincula'));
    });

    test('con la cuenta desactivada, tampoco', () async {
      nube.desactivadas.add(correo);

      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.motivo, MotivoAuth.cuentaRechazaClave);
      expect(r.error, contains('desactivada'));
    });

    test('una actual que no es de nadie sí es incorrecta', () async {
      final r = await auth.cambiarClave('cualquiera', 'Otra2026');
      expect(r.motivo, MotivoAuth.claveIncorrecta);
    });

    test('en una instalación sin Firebase dice cómo cambiarla', () async {
      nube.disponible = false;

      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.motivo, MotivoAuth.noDisponible);
      expect(r.error, contains('desvincula'));
    });

    test('si la señal se corta en el medio y el cambio llegó, al otro día '
        'se arregla solo', () async {
      nube
        ..forzarAlCambiar = FalloRemoto.incierto
        ..cambioLlegaIgual = true;

      final r = await auth.cambiarClave('Taller2026', 'Otra2026');
      expect(r.correcto, isFalse);
      expect(r.error, contains('no sabemos'));

      nube.forzarAlCambiar = null;

      // Con la vieja: la cuenta ya no la acepta, pero no deja afuera.
      expect(
        (await auth.entrar(clave: 'Taller2026')).motivo,
        MotivoAuth.cuentaRechazaClave,
      );
      // Con la nueva entra, y queda guardada.
      expect((await auth.entrar(clave: 'Otra2026')).correcto, isTrue);
    });
  });

  group('recuperación', () {
    test('sin correo vinculado no manda nada', () async {
      final r = await auth.enviarRecuperacion();
      expect(r.correcto, isFalse);
      expect(nube.enlaces, isEmpty);
    });

    test('manda al vinculado sin prometer que llegó', () async {
      await conCorreo();

      final r = await auth.enviarRecuperacion();
      expect(r.correcto, isTrue);
      expect(nube.enlaces, [correo]);
      expect(r.aviso, contains('Si esa dirección tiene cuenta'));
    });

    test('desde la ventana de vincular, a un correo escrito', () async {
      final r = await auth.enviarRecuperacion(correo: ' Otro@Correo.pe');
      expect(r.correcto, isTrue);
      expect(nube.enlaces, ['otro@correo.pe']);
    });

    test('sin señal lo dice', () async {
      await conCorreo();
      nube.forzar = FalloRemoto.sinConexion;

      expect((await auth.enviarRecuperacion()).motivo, MotivoAuth.sinConexion);
    });
  });

  group('desvincular', () {
    setUp(conCorreo);

    test('pide la contraseña del teléfono', () async {
      final r = await auth.desvincularCorreo('otra');
      expect(r.motivo, MotivoAuth.claveIncorrecta);
      expect((await auth.estado()).conCorreo, isTrue);
    });

    test('funciona sin señal', () async {
      nube.forzar = FalloRemoto.sinConexion;

      expect((await auth.desvincularCorreo('Taller2026')).correcto, isTrue);
      expect((await auth.estado()).conCorreo, isFalse);
    });
  });

  test('los códigos de Firebase se traducen', () {
    const esperados = {
      'network-request-failed': FalloRemoto.sinConexion,
      'invalid-credential': FalloRemoto.credenciales,
      'invalid-login-credentials': FalloRemoto.credenciales,
      'wrong-password': FalloRemoto.credenciales,
      'user-not-found': FalloRemoto.credenciales,
      'user-disabled': FalloRemoto.cuentaInactiva,
      'too-many-requests': FalloRemoto.demasiadosIntentos,
      'email-already-in-use': FalloRemoto.correoEnUso,
      'weak-password': FalloRemoto.claveDebil,
      'invalid-email': FalloRemoto.correoInvalido,
      'operation-not-allowed': FalloRemoto.noHabilitado,
      'algo-que-no-existe': FalloRemoto.desconocido,
    };

    esperados.forEach((codigo, fallo) {
      expect(falloDeCodigo(codigo), fallo, reason: codigo);
    });
  });
}
