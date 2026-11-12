import '../entities/trabajo.dart';

/// Una empresa a la que ya se le facturó, con el RUC que llevó esa vez.
typedef Facturado = ({String nombre, String ruc});

/// Los cuatro filtros del Historial. Vacío = sin filtrar.
class FiltroHistorial {
  const FiltroHistorial({
    this.desde = '',
    this.hasta = '',
    this.busqueda = '',
    this.tipo,
  });

  final String desde;
  final String hasta;

  /// Busca en cliente **y** en equipo.
  final String busqueda;

  /// `null` = todos los tipos.
  final TipoTrabajo? tipo;

  bool get vacio =>
      desde.isEmpty && hasta.isEmpty && busqueda.trim().isEmpty && tipo == null;

  FiltroHistorial copyWith({
    String? desde,
    String? hasta,
    String? busqueda,
    TipoTrabajo? tipo,
    bool quitarTipo = false,
  }) => FiltroHistorial(
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    busqueda: busqueda ?? this.busqueda,
    tipo: quitarTipo ? null : (tipo ?? this.tipo),
  );
}

/// Contrato de la capa de datos para ventas y trabajos.
///
/// La presentación habla con esta interfaz, nunca con SQLite: el día que se
/// agregue backup en la nube solo cambia la implementación.
abstract class TrabajosRepository {
  Future<Trabajo?> obtener(int id);

  /// Más reciente primero; a igual fecha, el último registrado arriba.
  Future<List<Trabajo>> listar([
    FiltroHistorial filtro = const FiltroHistorial(),
  ]);

  /// Crea el registro en estado `pendiente` con su correlativo, y devuelve el
  /// registro ya guardado (con id y código).
  Future<Trabajo> crear(Trabajo borrador);

  /// Guarda cambios y recalcula los totales sobre lo que quedó guardado.
  Future<Trabajo> actualizar(Trabajo trabajo);

  /// Marca como guardados **todos** los pasos `1..paso`, no solo el último:
  /// guardar en el paso 6 no puede perder lo anterior.
  Future<Trabajo> guardarPasosHasta(int id, int paso);

  /// Reabre un paso ya guardado.
  Future<Trabajo> editarPaso(int id, int paso);

  /// Cierra el registro: los totales quedan congelados tal como están.
  Future<Trabajo> terminar(int id);

  /// Elimina el registro y devuelve al stock todas sus líneas de inventario.
  Future<void> eliminar(int id);

  /// Las últimas [limite] empresas distintas a las que se facturó, de la más
  /// reciente a la más vieja.
  ///
  /// [exceptoId] deja afuera el registro que se está editando: se guarda
  /// mientras se escribe, y se sugeriría a sí mismo a medio escribir.
  Future<List<Facturado>> facturadosRecientes({int limite = 3, int? exceptoId});
}
