import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'cuenta_remota.dart';

/// La cuenta de correo, en Firebase Authentication (plan gratuito).
///
/// Es el **único** archivo que importa Firebase, y solo lo importa `main.dart`.
/// El resto de la app habla con [CuentaRemota]: los tests usan un falso, y la
/// vista web o un clon sin `google-services.json` usan [CuentaNoDisponible].
class CuentaFirebase implements CuentaRemota {
  CuentaFirebase._(this._auth);

  final FirebaseAuth _auth;

  /// Cuánto se espera a que responda un ingreso o un envío antes de darlo por
  /// sin señal.
  ///
  /// **No** se aplica a lo que escribe en la cuenta —crearla, cambiar la
  /// contraseña—: un plazo vencido no cancela la llamada, y decir "no se hizo"
  /// cuando igual llegó deja la contraseña de la cuenta y la del teléfono
  /// distintas. Ahí se espera al error de red del propio Firebase.
  static const Duration _plazo = Duration(seconds: 15);

  /// Arranca Firebase si se puede. Nunca falla: sin configuración, sin Google
  /// Play Services o en el navegador, la app sigue igual, sin recuperación.
  static Future<CuentaRemota> iniciar() async {
    final enCelular = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!enCelular) return const CuentaNoDisponible();

    try {
      // Arrancar Firebase no usa la red —lee la configuración del propio
      // APK—, así que si tarda más que esto, algo anda mal.
      await Firebase.initializeApp().timeout(const Duration(seconds: 3));
      final auth = FirebaseAuth.instance;
      // Los correos de recuperación y de confirmación salen en español.
      await auth.setLanguageCode('es');
      return CuentaFirebase._(auth);
    } catch (_) {
      return const CuentaNoDisponible();
    }
  }

  @override
  bool get disponible => true;

  @override
  Future<RespuestaRemota> crear(String correo, String clave) => _intentar(
        () => _auth.createUserWithEmailAndPassword(
          email: correo,
          password: clave,
        ),
      );

  @override
  Future<RespuestaRemota> entrar(String correo, String clave) => _intentar(
        () => _auth
            .signInWithEmailAndPassword(email: correo, password: clave)
            .timeout(_plazo),
      );

  @override
  Future<RespuestaRemota> cambiarClave(
    String correo,
    String actual,
    String nueva,
  ) async {
    final ingreso = await entrar(correo, actual);
    if (!ingreso.ok) return ingreso;

    final usuario = _auth.currentUser;
    if (usuario == null) {
      return const RespuestaRemota.fallo(FalloRemoto.desconocido);
    }

    final cambio = await _intentar(() => usuario.updatePassword(nueva));

    // Ya se había entrado: si ahora se cae la red, el cambio pudo llegar igual.
    return cambio.fallo == FalloRemoto.sinConexion
        ? const RespuestaRemota.fallo(FalloRemoto.incierto)
        : cambio;
  }

  @override
  Future<RespuestaRemota> enviarRecuperacion(String correo) => _intentar(
        () => _auth.sendPasswordResetEmail(email: correo).timeout(_plazo),
      );

  @override
  Future<bool> pedirConfirmacion() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null || usuario.emailVerified) return false;

      await usuario.sendEmailVerification();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<RespuestaRemota> _intentar(
    Future<Object?> Function() accion,
  ) async {
    try {
      await accion();
      return const RespuestaRemota.ok();
    } on FirebaseAuthException catch (e) {
      return RespuestaRemota.fallo(falloDeCodigo(e.code));
    } on TimeoutException {
      return const RespuestaRemota.fallo(FalloRemoto.sinConexion);
    } catch (_) {
      return const RespuestaRemota.fallo(FalloRemoto.desconocido);
    }
  }
}
