/// Por qué no respondió bien la cuenta de correo.
enum FalloRemoto {
  /// Correo o contraseña que la cuenta no acepta.
  credenciales,

  /// La cuenta existe pero está desactivada.
  cuentaInactiva,

  /// No hubo respuesta: sin señal o demasiado lenta.
  sinConexion,

  /// La operación escribía en la cuenta y la red se cayó en el medio: puede
  /// haber llegado o no. No es lo mismo que [sinConexion], donde se sabe que
  /// no pasó nada.
  incierto,

  correoEnUso,
  claveDebil,
  correoInvalido,
  demasiadosIntentos,

  /// El ingreso con correo no está activado en el proyecto de Firebase.
  noHabilitado,

  desconocido,
}

class RespuestaRemota {
  const RespuestaRemota.ok() : fallo = null;
  const RespuestaRemota.fallo(FalloRemoto this.fallo);

  final FalloRemoto? fallo;

  bool get ok => fallo == null;
}

/// La cuenta de correo, del otro lado.
///
/// Existe como contrato para que la lógica del acceso se pueda probar sin
/// Firebase, y para que la vista web y un build sin configuración funcionen
/// igual, solo que sin recuperación por correo.
abstract class CuentaRemota {
  /// ¿Esta instalación puede hablar con la cuenta?
  bool get disponible;

  Future<RespuestaRemota> crear(String correo, String clave);

  Future<RespuestaRemota> entrar(String correo, String clave);

  /// Entra con [actual] y cambia a [nueva].
  Future<RespuestaRemota> cambiarClave(
    String correo,
    String actual,
    String nueva,
  );

  /// Con la protección contra enumeración de Firebase —activa por defecto—
  /// esto termina bien aunque el correo no tenga cuenta: nunca afirmar que el
  /// enlace llegó.
  Future<RespuestaRemota> enviarRecuperacion(String correo);

  /// Pide confirmar la dirección de la cuenta con la que se acaba de entrar.
  /// Devuelve si mandó el correo. Nunca falla: si no puede, no pasa nada.
  Future<bool> pedirConfirmacion();
}

/// Sin cuenta de correo: la vista web, los tests que no la necesitan, un build
/// sin `google-services.json`.
class CuentaNoDisponible implements CuentaRemota {
  const CuentaNoDisponible();

  static const _nada = RespuestaRemota.fallo(FalloRemoto.desconocido);

  @override
  bool get disponible => false;

  @override
  Future<RespuestaRemota> crear(String correo, String clave) async => _nada;

  @override
  Future<RespuestaRemota> entrar(String correo, String clave) async => _nada;

  @override
  Future<RespuestaRemota> cambiarClave(
    String correo,
    String actual,
    String nueva,
  ) async =>
      _nada;

  @override
  Future<RespuestaRemota> enviarRecuperacion(String correo) async => _nada;

  @override
  Future<bool> pedirConfirmacion() async => false;
}

/// Traduce el código de error de Firebase Authentication.
///
/// Los códigos salen del plugin 6.x. Con la protección contra enumeración,
/// "no existe" y "contraseña equivocada" llegan los dos como
/// `invalid-credential` —o `invalid-login-credentials` en Android—; los viejos
/// se siguen aceptando por si el proyecto la tiene apagada.
FalloRemoto falloDeCodigo(String codigo) => switch (codigo) {
      'network-request-failed' => FalloRemoto.sinConexion,
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' ||
      'user-mismatch' =>
        FalloRemoto.credenciales,
      'user-disabled' => FalloRemoto.cuentaInactiva,
      'too-many-requests' => FalloRemoto.demasiadosIntentos,
      'email-already-in-use' => FalloRemoto.correoEnUso,
      'weak-password' => FalloRemoto.claveDebil,
      'invalid-email' || 'missing-email' => FalloRemoto.correoInvalido,
      'operation-not-allowed' => FalloRemoto.noHabilitado,
      _ => FalloRemoto.desconocido,
    };
