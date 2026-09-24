import '../entities/linea.dart';
import '../entities/repuesto.dart';

/// Lo que devuelve agregar un repuesto: las líneas que quedaron y, si hizo
/// falta dividirlas, el aviso para mostrarle al usuario.
class ResultadoLineas {
  const ResultadoLineas(this.lineas, [this.aviso]);

  final List<LineaRepuesto> lineas;
  final String? aviso;
}

/// Contrato del inventario y de la lógica de stock ↔ líneas de repuesto.
///
/// El stock se mueve **al agregar y al quitar cada línea**, no al guardar el
/// registro: eso hace que el inventario refleje la realidad aunque el trabajo
/// quede a medias.
abstract class InventarioRepository {
  Future<List<Repuesto>> listar();
  Future<Repuesto?> obtener(int id);

  /// El escáner consulta por acá, no por nombre.
  Future<Repuesto?> buscarPorCodigo(String? codigo);

  /// Coincidencia exacta de nombre, ignorando tildes y mayúsculas. Es lo que
  /// impide crear dos "MOTOR" —uno agotado para siempre y otro con stock—.
  Future<Repuesto?> porNombreExacto(String nombre);

  /// ¿Otro repuesto ya usa ese código de barras? Uno repetido rompería la
  /// búsqueda al vender, así que se bloquea al guardar.
  Future<bool> codigoRepetido(String? codigo, {int? exceptoId});

  Future<int> crear(Repuesto repuesto);
  Future<void> actualizar(Repuesto repuesto);
  Future<void> eliminar(int id);

  /// Suma unidades al stock de un repuesto que ya existe.
  Future<void> sumarStock(int id, int cantidad);

  /// Resuelve una línea de repuesto y ajusta el stock en consecuencia.
  ///
  /// - Sin `inventarioId` → línea externa, precio libre, no toca el stock.
  /// - Con stock suficiente → una línea de inventario, se descuenta.
  /// - Con stock insuficiente → **se divide sola**: una línea de inventario
  ///   con todo lo disponible + una línea externa con el resto, más un aviso.
  ///
  /// El `costo` solo hace falta para lo externo: lo que sale del inventario
  /// ya sabe lo que costó y se copia del repuesto.
  Future<ResultadoLineas> agregarRepuesto({
    int? inventarioId,
    required String desc,
    required int cant,
    double? precio,
    double? costo,
  });

  /// Deshace una línea: si era de inventario devuelve la cantidad al stock.
  Future<void> devolverRepuesto(LineaRepuesto linea);
  Future<void> devolverRepuestos(List<LineaRepuesto> lineas);

  /// Lo contrario: vuelve a sacar del stock una línea que ya existía. No
  /// divide ni avisa — no es un alta nueva, es restaurar lo que ya estaba.
  Future<void> retomarRepuesto(LineaRepuesto linea);

  /// Deja el stock como estaba al abrir la pantalla. En un alta nueva
  /// `originales` es la lista vacía y la misma función devuelve todo: no hay
  /// dos caminos.
  Future<void> restaurarRepuestos(
    List<LineaRepuesto> actuales,
    List<LineaRepuesto> originales,
  );
}
