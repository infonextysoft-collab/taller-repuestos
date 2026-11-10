import '../entities/recordatorio.dart';
import '../entities/repeticion.dart';
import '../entities/trabajo.dart';

/// Contrato de los recordatorios de mantenimiento.
abstract class RecordatoriosRepository {
  Future<Recordatorio?> obtener(int id);

  /// Los eliminados solo se piden desde el historial: para todo lo demás —el
  /// número rojo, "hoy toca"— es como si ya no estuvieran.
  Future<List<Recordatorio>> listar({
    bool incluirCumplidos = true,
    bool incluirEliminados = false,
  });

  /// Los mismos, agrupados por mes para la lista.
  Future<List<GrupoRecordatorios>> listarPorMes({bool incluirCumplidos = true});

  Future<int> contarVencidos();

  Future<int> crear(Recordatorio recordatorio);

  /// Nace del checkbox del paso de Recomendaciones: hereda cliente, equipo y
  /// el texto de la recomendación, sin volver a escribirlo.
  Future<int> crearDesdeTrabajo(Trabajo trabajo, Repeticion cada);

  /// Si le cambian la fecha, recalcula el estado: reprogramar un vencido para
  /// más adelante tiene que devolverlo a pendiente, o seguiría contando en el
  /// aviso rojo con una fecha que ya no vencía. Los cumplidos y los eliminados
  /// no cambian de estado.
  Future<void> actualizar(Recordatorio recordatorio);

  /// Lo pasa al historial como eliminado, sin programar el siguiente.
  Future<void> eliminar(int id);

  /// Lo pasa al historial como eliminado **y programa el siguiente**: se
  /// saltea esta vez, el mantenimiento sigue.
  ///
  /// Devuelve el id del siguiente, o `null` si no se repite.
  Future<int?> eliminarYSeguir(int id);

  /// Este se queda donde está, pero al cumplirlo ya no nace otro.
  Future<void> dejarDeRepetir(int id);

  /// Borra de verdad. Solo funciona con los que ya están eliminados.
  Future<void> borrarParaSiempre(int id);

  /// Marca o desmarca como importante.
  Future<void> marcarImportante(int id, bool importante);

  /// Marca cumplido y, si es recurrente, deja creado el siguiente contando
  /// **desde la fecha programada, no desde hoy**: un mantenimiento atendido
  /// tarde no corre todo el calendario hacia adelante.
  ///
  /// Devuelve el id del siguiente, o `null` si no se repite.
  Future<int?> marcarCumplido(int id);

  /// Pasa a vencido todo lo pendiente cuya fecha ya quedó atrás. Corre una
  /// vez al abrir la app, antes de mostrar el aviso.
  Future<int> refrescarVencidos();
}
