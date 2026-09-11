/// Resultado de una operación de credenciales.
class ResultadoAuth {
  const ResultadoAuth.ok()
      : correcto = true,
        error = null;
  const ResultadoAuth.error(this.error) : correcto = false;

  final bool correcto;
  final String? error;
}

/// Acceso a la app.
///
/// La clave se guarda tal cual, sin hashear: la app corre entera en el
/// dispositivo y no hay nada del otro lado que proteger. El login es una traba
/// de uso, no un candado.
abstract class AuthRepository {
  /// El usuario **no** distingue mayúsculas; la clave sí.
  Future<bool> validarLogin(String usuario, String clave);

  Future<String> usuarioActual();

  /// Exige la clave actual para que nadie la cambie con la sesión ajena abierta.
  Future<ResultadoAuth> cambiarClave(String claveActual, String claveNueva);

  /// ¿Sigue con la clave de fábrica? Solo para el aviso de primer ingreso.
  Future<bool> esClaveInicial();

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
