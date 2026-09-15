import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/clave_segura.dart';
import '../../core/utils/fechas.dart';
import '../../core/utils/validacion.dart';
import '../../domain/repositories/auth_repository.dart';
import '../cuenta/cuenta_remota.dart';
import '../local/app_database.dart';

/// La huella de la contraseña en SQLite, el día de la sesión en preferencias
/// y, si hay, la cuenta de correo del otro lado. Ver [AuthRepository] para la
/// regla de quién decide.
class AuthRepositorySqlite implements AuthRepository {
  /// [vueltas] y [reloj] existen para los tests: una huella de verdad tarda,
  /// y el freno de intentos se prueba haciendo pasar el tiempo.
  AuthRepositorySqlite(
    this._base,
    this._remota, {
    int? vueltas,
    Duration Function()? reloj,
  })  : _vueltas = vueltas ?? vueltasClave,
        _reloj = reloj ?? _relojMonotonico();

  /// Guarda la **fecha** en que se entró, no un sí/no.
  ///
  /// Es una clave nueva: la vieja guardaba un booleano y leerla como texto
  /// reventaría. Al entrar la primera vez se limpia sola.
  static const String _claveSesion = 'sesion_dia';
  static const String _claveSesionVieja = 'sesion_abierta';

  static const String _claveFallos = 'auth_fallos';
  static const String _claveEspera = 'auth_espera_ms';

  /// El freno de intentos.
  ///
  /// Sin señal la huella es lo único que se compara, y sin freno se podrían
  /// probar contraseñas sin límite con el teléfono en modo avión. Los primeros
  /// cinco errores son gratis —con las manos sucias uno se equivoca— y desde
  /// el sexto hay que esperar, cada vez el doble, hasta cinco minutos.
  ///
  /// La espera se guarda como **lo que falta** y se descuenta con un reloj que
  /// no se toca desde los ajustes del teléfono. Guardar "hasta qué hora" dejaba
  /// dos agujeros: adelantar la hora del teléfono la saltaba, y un reloj que
  /// vuelve atrás —un celular que se apagó sin batería y arrancó en otra
  /// fecha— dejaba a la persona afuera horas. A cambio, la espera solo corre
  /// con la app abierta: cerrarla no la termina.
  static const int _fallosLibres = 5;
  static const Duration _esperaInicial = Duration(seconds: 30);
  static const Duration _esperaMaxima = Duration(minutes: 5);

  final AppDatabase _base;
  final CuentaRemota _remota;
  final int _vueltas;
  final Duration Function() _reloj;

  /// Cuándo, según [_reloj], se guardó por última vez lo que faltaba esperar.
  Duration? _marca;

  Database get _db => _base.db;

  static Duration Function() _relojMonotonico() {
    final cronometro = Stopwatch()..start();
    return () => cronometro.elapsed;
  }

  /* --------------------------------------------------------------- estado */

  @override
  Future<EstadoCuenta> estado() async {
    final fila = await _fila();
    return EstadoCuenta(
      usuario: fila.usuario,
      correo: fila.correo,
      nubeDisponible: _remota.disponible,
      claveDeFabrica: fila.deFabrica,
    );
  }

  Future<_Fila> _fila() async {
    final filas = await _db.query('auth', where: 'id = 1', limit: 1);
    return _Fila.de(filas.isEmpty ? const {} : filas.first);
  }

  /* --------------------------------------------------------------- entrar */

  @override
  Future<ResultadoAuth> entrar({
    String usuario = '',
    required String clave,
  }) async {
    final espera = await _esperaPendiente();
    if (espera != null) return espera;

    final fila = await _fila();
    final correo = fila.correo;

    // Sin correo: usuario y contraseña de este teléfono, como siempre.
    if (correo == null) {
      const incorrectos = 'Usuario o contraseña incorrectos.';
      if (usuario.trim().toLowerCase() != fila.usuario.toLowerCase()) {
        await _anotarFallo();
        return const ResultadoAuth.error(
          incorrectos,
          motivo: MotivoAuth.claveIncorrecta,
        );
      }
      return await _verificarLocal(fila, clave, siFalla: incorrectos) ??
          const ResultadoAuth.ok();
    }

    if (!_remota.disponible) {
      return await _verificarLocal(fila, clave) ?? const ResultadoAuth.ok();
    }

    final respuesta = await _remota.entrar(correo, clave);

    switch (respuesta.fallo) {
      case null:
        // La cuenta la aceptó: queda como la de este teléfono, por si se
        // cambió con el enlace del correo.
        if (!await _coincideLocal(fila, clave)) await _guardarClave(clave);
        await _limpiarFallos();
        return const ResultadoAuth.ok();

      case FalloRemoto.credenciales || FalloRemoto.cuentaInactiva:
        if (await _coincideLocal(fila, clave)) {
          // Es la contraseña buena del teléfono: no es un error que cuente.
          await _limpiarFallos();
          return ResultadoAuth.error(
            respuesta.fallo == FalloRemoto.cuentaInactiva
                ? 'Tu cuenta de correo está desactivada y no acepta esta '
                    'contraseña.'
                : 'Tu cuenta de correo ya no acepta esta contraseña. Si la '
                    'cambiaste con el enlace del correo, entra con la nueva.',
            motivo: MotivoAuth.cuentaRechazaClave,
          );
        }
        await _anotarFallo();
        return const ResultadoAuth.error(
          'Contraseña incorrecta.',
          motivo: MotivoAuth.claveIncorrecta,
        );

      case FalloRemoto.sinConexion:
        return await _verificarLocal(
              fila,
              clave,
              siFalla: 'Sin conexión, y esa no es la última contraseña que '
                  'usaste aquí. Si la cambiaste con el enlace del correo, '
                  'conéctate una vez para entrar con la nueva.',
            ) ??
            const ResultadoAuth.ok();

      // Firebase frenando intentos, sin configurar o con un error raro: decide
      // la huella, igual que sin señal. Si no, le enseña a usar modo avión.
      default:
        return await _verificarLocal(fila, clave) ?? const ResultadoAuth.ok();
    }
  }

  /* -------------------------------------------------------- cambiar clave */

  @override
  Future<ResultadoAuth> cambiarClave(String actual, String nueva) async {
    if (nueva.length < kMinimoClave) {
      return const ResultadoAuth.error(
        'La nueva necesita al menos $kMinimoClave caracteres.',
        motivo: MotivoAuth.claveCorta,
      );
    }
    if (nueva == claveInicial) {
      return const ResultadoAuth.error(
        'Esa es la contraseña de fábrica: elige otra.',
        motivo: MotivoAuth.claveDeFabrica,
      );
    }

    final espera = await _esperaPendiente();
    if (espera != null) return espera;

    final fila = await _fila();
    final correo = fila.correo;

    if (correo == null) {
      final error = await _verificarLocal(
        fila,
        actual,
        siFalla: 'La contraseña actual no es correcta.',
      );
      if (error != null) return error;

      await _guardarClave(nueva);
      return const ResultadoAuth.ok();
    }

    // Con correo, la actual la valida la cuenta y no la huella: la huella pudo
    // quedar vieja si la contraseña se cambió con el enlace del correo.
    if (!_remota.disponible) {
      return const ResultadoAuth.error(
        'Tu contraseña es la de tu cuenta de correo, y esta instalación no '
        'puede conectarse a ella. Para cambiarla solo en este teléfono, '
        'desvincula el correo en Negocio › Recuperación por correo.',
        motivo: MotivoAuth.noDisponible,
      );
    }

    final respuesta = await _remota.cambiarClave(correo, actual, nueva);

    switch (respuesta.fallo) {
      case null:
        await _guardarClave(nueva);
        await _limpiarFallos();
        return const ResultadoAuth.ok();

      case FalloRemoto.credenciales || FalloRemoto.cuentaInactiva:
        // Si es la del teléfono, no se equivocó al escribirla: la cuenta
        // cambió o se desactivó. Decirle "incorrecta" sería mentirle y dejarlo
        // sin salida.
        if (await _coincideLocal(fila, actual)) {
          await _limpiarFallos();
          return ResultadoAuth.error(
            respuesta.fallo == FalloRemoto.cuentaInactiva
                ? 'Tu cuenta de correo está desactivada y no deja cambiar la '
                    'contraseña. Para cambiarla solo en este teléfono, '
                    'desvincula el correo en Negocio › Recuperación por correo.'
                : 'Tu cuenta de correo ya no acepta esta contraseña. Si la '
                    'cambiaste con el enlace del correo, escribe esa como la '
                    'actual; si no, desvincula el correo en Negocio › '
                    'Recuperación por correo para cambiarla solo aquí.',
            motivo: MotivoAuth.cuentaRechazaClave,
          );
        }
        await _anotarFallo();
        return const ResultadoAuth.error(
          'La contraseña actual no es correcta.',
          motivo: MotivoAuth.claveIncorrecta,
        );

      case FalloRemoto.sinConexion:
        return const ResultadoAuth.error(
          'Hace falta internet: tu contraseña es la de tu cuenta de correo.',
          motivo: MotivoAuth.sinConexion,
        );

      // Si llegó, mañana la vieja da "tu cuenta ya no acepta esta contraseña"
      // y la nueva entra; si no llegó, la vieja sigue entrando. No hay que
      // guardar nada a medias.
      case FalloRemoto.incierto:
        return const ResultadoAuth.error(
          'Se cortó la señal y no sabemos si el cambio llegó. Cuando tengas '
          'internet, entra con la nueva; si no la acepta, sigue valiendo la '
          'anterior.',
          motivo: MotivoAuth.sinConexion,
        );

      default:
        return _errorRemoto(respuesta.fallo!, 'cambiar la contraseña');
    }
  }

  /* ------------------------------------------------------------- vincular */

  @override
  Future<ResultadoAuth> vincularCorreo({
    required String correo,
    required String claveApp,
    String? claveCuenta,
  }) async {
    final fila = await _fila();

    if (fila.correo != null) {
      return const ResultadoAuth.error(
        'Este teléfono ya tiene un correo vinculado. Desvincúlalo primero para '
        'poner otro.',
      );
    }
    if (!_remota.disponible) return _noDisponible;

    final destino = correo.trim().toLowerCase();
    if (!_pareceCorreo(destino)) return _correoMalEscrito;

    // Esa contraseña está en el README: una cuenta con ella es de cualquiera.
    // Se mira el estado y también lo escrito, por las dos puertas.
    if (fila.deFabrica) {
      return const ResultadoAuth.error(
        'Primero cambia la contraseña de fábrica: la cuenta de correo no puede '
        'usarla.',
        motivo: MotivoAuth.claveDeFabrica,
      );
    }
    if (claveApp == claveInicial || claveCuenta == claveInicial) {
      return const ResultadoAuth.error(
        'Esa es la contraseña de fábrica: la cuenta de correo no puede usarla.',
        motivo: MotivoAuth.claveDeFabrica,
      );
    }

    // La de este teléfono autoriza siempre, venga o no la de la cuenta.
    final error = await _verificarLocal(
      fila,
      claveApp,
      siFalla: 'Esa no es la contraseña de esta app.',
    );
    if (error != null) return error;

    final cuentaAparte = claveCuenta != null && claveCuenta != claveApp;

    if (!cuentaAparte) {
      if (claveApp.length < kMinimoClave) {
        return const ResultadoAuth.error(
          'Tu contraseña es muy corta para la cuenta de correo. Cámbiala '
          'primero por una de al menos $kMinimoClave caracteres.',
          motivo: MotivoAuth.claveCorta,
        );
      }

      var respuesta = await _remota.crear(destino, claveApp);
      if (respuesta.fallo == FalloRemoto.correoEnUso) {
        respuesta = await _remota.entrar(destino, claveApp);
        if (respuesta.fallo == FalloRemoto.credenciales) {
          return const ResultadoAuth.error(
            'Ese correo ya tiene una cuenta con otra contraseña. Escríbela '
            'para vincularla a este teléfono.',
            motivo: MotivoAuth.cuentaConOtraClave,
          );
        }
      }
      if (!respuesta.ok) {
        return _errorRemoto(respuesta.fallo!, 'vincular el correo');
      }
      return _vincular(destino);
    }

    final respuesta = await _remota.entrar(destino, claveCuenta);
    if (respuesta.fallo == FalloRemoto.credenciales) {
      return const ResultadoAuth.error(
        'Esa no es la contraseña de tu cuenta de correo.',
        motivo: MotivoAuth.cuentaConOtraClave,
      );
    }
    if (!respuesta.ok) {
      return _errorRemoto(respuesta.fallo!, 'vincular el correo');
    }

    await _guardarClave(claveCuenta);
    return _vincular(destino);
  }

  Future<ResultadoAuth> _vincular(String correo) async {
    await _db.update('auth', {'correo': correo}, where: 'id = 1');

    // Un correo mal escrito no avisa solo: la confirmación que no llega es la
    // única señal de que hay que corregirlo.
    final pidioConfirmar = await _remota.pedirConfirmacion();
    return ResultadoAuth.ok(
      aviso: pidioConfirmar
          ? 'Listo. Te mandamos un correo para confirmar la dirección. Si no '
              'te llega en unos minutos, revisa el spam; si tampoco está ahí, '
              'el correo quedó mal escrito: desvincúlalo y ponlo de nuevo.'
          : 'Listo. Si olvidas la contraseña, te mandamos un enlace a ese '
              'correo.',
    );
  }

  @override
  Future<ResultadoAuth> desvincularCorreo(String claveApp) async {
    final fila = await _fila();
    if (fila.correo == null) return const ResultadoAuth.ok();

    final error = await _verificarLocal(
      fila,
      claveApp,
      siFalla: 'Esa no es la contraseña de este teléfono.',
    );
    if (error != null) return error;

    await _db.update('auth', {'correo': null}, where: 'id = 1');
    return const ResultadoAuth.ok();
  }

  /* ---------------------------------------------------------- recuperación */

  @override
  Future<ResultadoAuth> enviarRecuperacion({String? correo}) async {
    final destino = (correo ?? (await _fila()).correo ?? '').trim().toLowerCase();

    if (destino.isEmpty) {
      return const ResultadoAuth.error(
        'Este teléfono no tiene un correo vinculado.',
      );
    }
    if (!_remota.disponible) return _noDisponible;
    if (!_pareceCorreo(destino)) return _correoMalEscrito;

    final respuesta = await _remota.enviarRecuperacion(destino);
    if (!respuesta.ok) return _errorRemoto(respuesta.fallo!, 'enviar el enlace');

    // Firebase responde bien aunque la dirección no tenga cuenta: no se puede
    // prometer que llegó.
    return const ResultadoAuth.ok(
      aviso: 'Si esa dirección tiene cuenta, en unos minutos te llega el '
          'enlace. Revisa también el spam. La primera vez que entres con la '
          'nueva vas a necesitar internet.',
    );
  }

  /* -------------------------------------------------------------- sesión */

  @override
  Future<bool> haySesion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveSesion) == hoyISO();
  }

  @override
  Future<void> abrirSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesionVieja);
    await prefs.setString(_claveSesion, hoyISO());
  }

  @override
  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveSesion);
  }

  /* ------------------------------------------------------------- huella */

  /// ¿Es la contraseña de este teléfono? Sin huella, es la de fábrica.
  ///
  /// La huella se calcula fuera del hilo de la pantalla: en un celular de gama
  /// baja son uno o dos segundos, y en el hilo principal congelarían el botón
  /// que se acaba de tocar.
  Future<bool> _coincideLocal(_Fila fila, String clave) async {
    final huella = fila.huella;
    if (huella == null) {
      return igualesEnTiempoConstante(
        utf8.encode(clave),
        utf8.encode(claveInicial),
      );
    }
    return compute(_coincide, (huella, clave));
  }

  static bool _coincide((HuellaClave, String) datos) =>
      datos.$1.coincide(datos.$2);

  Future<void> _guardarClave(String clave) async {
    // La de fábrica se guarda igual que en la migración: sin huella. Con
    // huella dejaría de reconocerse como de fábrica, y eso abría la puerta a
    // vincular una cuenta de correo con la contraseña del README.
    if (clave == claveInicial) {
      await _db.update(
        'auth',
        {
          'clave': '',
          'claveHuella': null,
          'claveSal': null,
          'claveVueltas': null,
        },
        where: 'id = 1',
      );
      return;
    }

    final huella = await compute(_huellaDe, (clave, _vueltas));
    await _db.update(
      'auth',
      {
        'clave': '',
        'claveHuella': huella.huella,
        'claveSal': huella.sal,
        'claveVueltas': huella.vueltas,
      },
      where: 'id = 1',
    );
  }

  static HuellaClave _huellaDe((String, int) datos) =>
      HuellaClave.de(datos.$1, vueltas: datos.$2);

  /// Compara contra la huella con el freno puesto. `null` si coincide.
  Future<ResultadoAuth?> _verificarLocal(
    _Fila fila,
    String clave, {
    String siFalla = 'Contraseña incorrecta.',
  }) async {
    final espera = await _esperaPendiente();
    if (espera != null) return espera;

    if (await _coincideLocal(fila, clave)) {
      await _limpiarFallos();
      return null;
    }

    await _anotarFallo();
    return ResultadoAuth.error(siFalla, motivo: MotivoAuth.claveIncorrecta);
  }

  /* ---------------------------------------------------- freno de intentos */

  Future<ResultadoAuth?> _esperaPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getInt(_claveEspera);
    if (guardado == null) return null;

    final ahora = _reloj();
    final marca = _marca;
    final pasado = marca == null ? Duration.zero : ahora - marca;

    var falta = Duration(milliseconds: guardado) - pasado;
    if (falta > _esperaMaxima) falta = _esperaMaxima;

    if (falta <= Duration.zero) {
      await prefs.remove(_claveEspera);
      _marca = null;
      return null;
    }

    await prefs.setInt(_claveEspera, falta.inMilliseconds);
    _marca = ahora;

    return ResultadoAuth.error(
      'Demasiados intentos seguidos. Espera ${_cuanto(falta)} y vuelve a '
      'probar.',
      motivo: MotivoAuth.esperar,
    );
  }

  Future<void> _anotarFallo() async {
    final prefs = await SharedPreferences.getInstance();
    final fallos = (prefs.getInt(_claveFallos) ?? 0) + 1;
    await prefs.setInt(_claveFallos, fallos);

    if (fallos <= _fallosLibres) return;

    // Se duplica con cada error de más, hasta el tope.
    final dobles = (fallos - _fallosLibres - 1).clamp(0, 10);
    var espera = _esperaInicial * (1 << dobles);
    if (espera > _esperaMaxima) espera = _esperaMaxima;

    await prefs.setInt(_claveEspera, espera.inMilliseconds);
    _marca = _reloj();
  }

  Future<void> _limpiarFallos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveFallos);
    await prefs.remove(_claveEspera);
    _marca = null;
  }

  static String _cuanto(Duration falta) {
    final segundos = (falta.inMilliseconds / 1000).ceil();
    if (segundos < 60) return segundos == 1 ? '1 segundo' : '$segundos segundos';

    final minutos = (segundos / 60).ceil();
    return minutos == 1 ? '1 minuto' : '$minutos minutos';
  }

  /* ------------------------------------------------------------- errores */

  static bool _pareceCorreo(String correo) =>
      correo.isNotEmpty && Valida.email()(correo) == null;

  static const _noDisponible = ResultadoAuth.error(
    'La recuperación por correo solo funciona en la app instalada en el '
    'celular.',
    motivo: MotivoAuth.noDisponible,
  );

  static const _correoMalEscrito = ResultadoAuth.error(
    'Ese correo está mal escrito.',
    motivo: MotivoAuth.correoInvalido,
  );

  static ResultadoAuth _errorRemoto(FalloRemoto fallo, String paraQue) =>
      switch (fallo) {
        FalloRemoto.sinConexion || FalloRemoto.incierto => ResultadoAuth.error(
            'Hace falta internet para $paraQue.',
            motivo: MotivoAuth.sinConexion,
          ),
        FalloRemoto.claveDebil => const ResultadoAuth.error(
            'La cuenta de correo pide una contraseña más segura. Cámbiala por '
            'una más larga.',
            motivo: MotivoAuth.claveCorta,
          ),
        FalloRemoto.correoInvalido => _correoMalEscrito,
        FalloRemoto.demasiadosIntentos => const ResultadoAuth.error(
            'Demasiados intentos. Espera unos minutos y vuelve a probar.',
            motivo: MotivoAuth.esperar,
          ),
        FalloRemoto.noHabilitado => const ResultadoAuth.error(
            'El ingreso con correo no está activado en el proyecto de '
            'Firebase.',
            motivo: MotivoAuth.noDisponible,
          ),
        FalloRemoto.cuentaInactiva => const ResultadoAuth.error(
            'Esa cuenta de correo está desactivada.',
          ),
        FalloRemoto.credenciales => const ResultadoAuth.error(
            'Esa no es la contraseña de la cuenta.',
            motivo: MotivoAuth.claveIncorrecta,
          ),
        FalloRemoto.correoEnUso => const ResultadoAuth.error(
            'Ese correo ya tiene una cuenta.',
          ),
        FalloRemoto.desconocido => ResultadoAuth.error(
            'No se pudo $paraQue. Vuelve a probar en un rato.',
          ),
      };
}

/// La fila de `auth`, leída una vez.
class _Fila {
  const _Fila({required this.usuario, this.correo, this.huella});

  factory _Fila.de(Map<String, Object?> r) {
    final huella = r['claveHuella']?.toString() ?? '';
    final correo = r['correo']?.toString() ?? '';

    return _Fila(
      usuario: r['usuario']?.toString() ?? usuarioInicial,
      correo: correo.isEmpty ? null : correo,
      huella: huella.isEmpty
          ? null
          : HuellaClave(
              huella: huella,
              sal: r['claveSal']?.toString() ?? '',
              vueltas: (r['claveVueltas'] as num?)?.toInt() ?? kVueltasClave,
            ),
    );
  }

  final String usuario;
  final String? correo;

  /// Sin huella, la contraseña es la de fábrica.
  final HuellaClave? huella;

  bool get deFabrica => huella == null;
}
