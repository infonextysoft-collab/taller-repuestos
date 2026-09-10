import '../entities/negocio.dart';

/// Datos del emisor. Siempre un solo registro.
abstract class NegocioRepository {
  /// Si nunca se llenó, devuelve la forma vacía en vez de `null`.
  Future<Negocio> obtener();

  Future<Negocio> guardar(Negocio negocio);
}
