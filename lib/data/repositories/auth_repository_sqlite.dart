import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/fechas.dart';
import '../../domain/repositories/auth_repository.dart';
import '../local/app_database.dart';

/// Credenciales en SQLite; el día de la sesión, en preferencias.
class AuthRepositorySqlite implements AuthRepository {
  AuthRepositorySqlite(this._base);

  /// Guarda la **fecha** en que se entró, no un sí/no.
  ///
  /// Es una clave nueva: la vieja guardaba un booleano y leerla como texto
  /// reventaría. Al entrar la primera vez se limpia sola.
  static const String _claveSesion = 'sesion_dia';
  static const String _claveSesionVieja = 'sesion_abierta';

  final AppDatabase _base;
  Database get _db => _base.db;

  Future<Map<String, Object?>?> _fila() async {
    final filas = await _db.query('auth', where: 'id = 1', limit: 1);
    return filas.isEmpty ? null : filas.first;
  }

  @override
  Future<bool> validarLogin(String usuario, String clave) async {
    final auth = await _fila();
    if (auth == null) return false;

    final usuarioOk = usuario.trim().toLowerCase() ==
        auth['usuario'].toString().toLowerCase();
    final claveOk = clave == auth['clave'].toString();

    return usuarioOk && claveOk;
  }

  @override
  Future<String> usuarioActual() async =>
      (await _fila())?['usuario']?.toString() ?? usuarioInicial;

  @override
  Future<ResultadoAuth> cambiarClave(
      String claveActual, String claveNueva) async {
    final auth = await _fila();
    if (auth == null) {
      return const ResultadoAuth.error('No hay un usuario configurado.');
    }

    if (claveActual != auth['clave'].toString()) {
      return const ResultadoAuth.error('La contraseña actual no es correcta.');
    }
    if (claveNueva.length < 4) {
      return const ResultadoAuth.error(
          'La nueva contraseña debe tener al menos 4 caracteres.');
    }

    await _db.update('auth', {'clave': claveNueva},
        where: 'id = 1');
    return const ResultadoAuth.ok();
  }

  @override
  Future<bool> esClaveInicial() async =>
      (await _fila())?['clave']?.toString() == claveInicial;

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
}
