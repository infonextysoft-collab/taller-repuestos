import '../entities/compra.dart';

/// Las compras: lo que entra al inventario y de dónde salió.
abstract class ComprasRepository {
  /// Las más recientes primero.
  Future<List<Compra>> listar({int? limite});

  /// Las que trajeron unidades de un repuesto, de la más nueva a la más vieja.
  Future<List<Compra>> deRepuesto(int inventarioId, {int limite = 3});

  /// Guarda la compra, **suma el stock** de cada renglón y deja el precio de
  /// compra del repuesto en lo que se acaba de pagar.
  Future<Compra> registrar(Compra compra);

  /// Borra la compra y saca del stock lo que había entrado con ella.
  Future<void> eliminar(int id);

  /// Los proveedores a los que más se les compra, para ofrecerlos de a un
  /// toque en vez de escribirlos de nuevo.
  Future<List<String>> proveedoresFrecuentes({int limite = 4});
}
