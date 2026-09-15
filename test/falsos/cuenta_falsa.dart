import 'package:taller_repuestos/data/cuenta/cuenta_remota.dart';

/// Una cuenta de correo de mentira, con la "nube" en un mapa.
///
/// Se comporta como Firebase en lo que importa para la lógica: no deja crear
/// dos cuentas con el mismo correo, exige 6 caracteres, y el envío de
/// recuperación responde bien aunque el correo no tenga cuenta.
class CuentaFalsa implements CuentaRemota {
  CuentaFalsa({this.disponible = true});

  @override
  bool disponible;

  /// La nube: correo → contraseña.
  final Map<String, String> cuentas = {};

  /// Correos de cuentas desactivadas.
  final Set<String> desactivadas = {};

  /// Si está puesto, toda llamada falla así: por ejemplo, sin señal.
  FalloRemoto? forzar;

  /// Solo para el cambio de contraseña, después de haber entrado.
  FalloRemoto? forzarAlCambiar;

  /// Con [forzarAlCambiar] en `incierto`: ¿el cambio llegó igual?
  bool cambioLlegaIgual = false;

  bool correoVerificado = false;

  final List<String> llamadas = [];
  final List<String> enlaces = [];
  int confirmaciones = 0;

  String? _dentro;

  @override
  Future<RespuestaRemota> crear(String correo, String clave) async {
    llamadas.add('crear:$correo');
    if (forzar != null) return RespuestaRemota.fallo(forzar!);
    if (cuentas.containsKey(correo)) {
      return const RespuestaRemota.fallo(FalloRemoto.correoEnUso);
    }
    if (clave.length < 6) {
      return const RespuestaRemota.fallo(FalloRemoto.claveDebil);
    }

    cuentas[correo] = clave;
    _dentro = correo;
    return const RespuestaRemota.ok();
  }

  @override
  Future<RespuestaRemota> entrar(String correo, String clave) async {
    llamadas.add('entrar:$correo');
    if (forzar != null) return RespuestaRemota.fallo(forzar!);
    if (desactivadas.contains(correo)) {
      return const RespuestaRemota.fallo(FalloRemoto.cuentaInactiva);
    }
    if (cuentas[correo] != clave) {
      return const RespuestaRemota.fallo(FalloRemoto.credenciales);
    }

    _dentro = correo;
    return const RespuestaRemota.ok();
  }

  @override
  Future<RespuestaRemota> cambiarClave(
    String correo,
    String actual,
    String nueva,
  ) async {
    final ingreso = await entrar(correo, actual);
    if (!ingreso.ok) return ingreso;

    llamadas.add('cambiar:$correo');
    if (forzarAlCambiar != null) {
      if (forzarAlCambiar == FalloRemoto.incierto && cambioLlegaIgual) {
        cuentas[correo] = nueva;
      }
      return RespuestaRemota.fallo(forzarAlCambiar!);
    }

    cuentas[correo] = nueva;
    return const RespuestaRemota.ok();
  }

  @override
  Future<RespuestaRemota> enviarRecuperacion(String correo) async {
    llamadas.add('recuperar:$correo');
    if (forzar != null) return RespuestaRemota.fallo(forzar!);

    enlaces.add(correo);
    return const RespuestaRemota.ok();
  }

  @override
  Future<bool> pedirConfirmacion() async {
    if (_dentro == null || correoVerificado) return false;
    confirmaciones++;
    return true;
  }
}
