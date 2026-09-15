/// Mínimo de caracteres de una contraseña.
///
/// Es el mínimo de la cuenta de correo (Firebase): al vincularla, la contraseña
/// de la app pasa a ser la de la cuenta, así que una más corta no serviría ahí.
const int kMinimoClave = 6;

/// Por qué no salió una operación de credenciales.
///
/// El mensaje ya viene listo para mostrar. Esto es para lo que la pantalla
/// tiene que **ofrecer** además de decirlo: un botón, un campo más.
enum MotivoAuth {
  /// La contraseña, o el usuario, no es la correcta.
  claveIncorrecta,

  /// Hace falta internet para lo que se pidió.
  sinConexion,

  /// Demasiados intentos seguidos: hay que esperar.
  esperar,

  /// Al entrar: la cuenta de correo ya no acepta esta contraseña, pero es la
  /// última con la que se entró en este teléfono. Se ofrece seguir sin la
  /// cuenta, que es lo mismo que pasaría sin señal.
  cuentaRechazaClave,

  /// Al vincular: ese correo ya tiene cuenta con otra contraseña. Se pide la
  /// de la cuenta.
  cuentaConOtraClave,

  /// Al vincular: sigue puesta la contraseña de fábrica.
  claveDeFabrica,

  /// Más corta que [kMinimoClave].
  claveCorta,

  correoInvalido,

  /// Esta instalación no puede hablar con la cuenta de correo.
  noDisponible,

  otro,
}

/// Resultado de una operación de credenciales.
class ResultadoAuth {
  const ResultadoAuth.ok({this.aviso})
      : correcto = true,
        error = null,
        motivo = null;

  const ResultadoAuth.error(String this.error, {this.motivo = MotivoAuth.otro})
      : correcto = false,
        aviso = null;

  final bool correcto;
  final String? error;
  final MotivoAuth? motivo;

  /// Algo que decir aunque haya salido bien: "revisa tu correo".
  final String? aviso;
}

/// Cómo está el acceso de este teléfono.
class EstadoCuenta {
  const EstadoCuenta({
    required this.usuario,
    this.correo,
    this.nubeDisponible = false,
    this.claveDeFabrica = false,
  });

  final String usuario;

  /// El correo vinculado para recuperar la contraseña. `null` si no hay.
  final String? correo;

  /// ¿Esta instalación puede hablar con la cuenta de correo? En la vista web,
  /// o en un build sin la configuración de Firebase, no.
  final bool nubeDisponible;

  final bool claveDeFabrica;

  bool get conCorreo => correo != null;
}

/// Acceso a la app.
///
/// **La contraseña de este teléfono es la que abre la app**, y se guarda como
/// huella, nunca tal cual. Opcionalmente se vincula un correo, que sirve para
/// una sola cosa: recuperar la contraseña con un enlace.
///
/// El correo no decide quién entra, y es a propósito. El técnico trabaja donde
/// no hay señal, y sin señal lo único que hay para comparar es la huella. Si con
/// señal la cuenta pudiera dejarlo afuera no se ganaría seguridad —en modo avión
/// esa misma contraseña entra— y sí podría quedar encerrado fuera de sus propios
/// datos por una cuenta borrada o un proyecto de Firebase rehecho.
abstract class AuthRepository {
  Future<EstadoCuenta> estado();

  /// Sin correo vinculado pide usuario —sin distinguir mayúsculas— y
  /// contraseña. Con correo, solo la contraseña: el usuario se ignora.
  ///
  /// Si la cuenta de correo acepta la contraseña, esa pasa a ser la de este
  /// teléfono. Así una clave cambiada con el enlace del correo queda al día en
  /// cuanto se entra con señal.
  Future<ResultadoAuth> entrar({String usuario = '', required String clave});

  /// Sin correo, exige la actual para que nadie la cambie con la sesión ajena
  /// abierta. Con correo, la contraseña es la de la cuenta: la valida la
  /// cuenta y hace falta internet.
  Future<ResultadoAuth> cambiarClave(String actual, String nueva);

  /// Vincula un correo para poder recuperar la contraseña. Necesita internet.
  ///
  /// [claveApp] es la contraseña de este teléfono y autoriza siempre. Si ese
  /// correo ya tiene cuenta con otra contraseña, se vuelve a llamar con
  /// [claveCuenta]; al vincular, esa pasa a ser también la de este teléfono
  /// —una sola contraseña para recordar—.
  Future<ResultadoAuth> vincularCorreo({
    required String correo,
    required String claveApp,
    String? claveCuenta,
  });

  /// Deja de usar el correo. Pide la contraseña de este teléfono y funciona
  /// sin señal. La cuenta de correo no se borra.
  Future<ResultadoAuth> desvincularCorreo(String claveApp);

  /// Manda el enlace para poner una contraseña nueva. Sin [correo], al
  /// vinculado.
  Future<ResultadoAuth> enviarRecuperacion({String? correo});

  /// ¿Hay una sesión abierta **de hoy**?
  ///
  /// La sesión dura el día: se guarda la fecha en que se entró, y al cambiar
  /// el día deja de valer. Se eligió así en vez de un cronómetro porque un
  /// cronómetro te echa a media tarde, con las manos sucias y el equipo
  /// abierto; esto pide la contraseña una vez por día y nunca en el medio de
  /// un trabajo.
  Future<bool> haySesion();

  Future<void> abrirSesion();
  Future<void> cerrarSesion();
}
