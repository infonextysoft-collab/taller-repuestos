import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/fechas.dart';
import '../../domain/entities/recordatorio.dart';
import '../../domain/entities/repeticion.dart';
import '../../domain/entities/trabajo.dart';
import '../../domain/repositories/recordatorios_repository.dart';
import '../local/app_database.dart';

/// Recordatorios de mantenimiento sobre SQLite.
class RecordatoriosRepositorySqlite implements RecordatoriosRepository {
  RecordatoriosRepositorySqlite(this._base);

  final AppDatabase _base;
  Database get _db => _base.db;

  @override
  Future<Recordatorio?> obtener(int id) async {
    final filas = await _db
        .query('recordatorios', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Recordatorio.fromRow(filas.first);
  }

  @override
  Future<List<Recordatorio>> listar({
    bool incluirCumplidos = true,
    bool incluirEliminados = false,
  }) async {
    final fuera = [
      if (!incluirCumplidos) "estado <> 'cumplido'",
      if (!incluirEliminados) "estado <> 'eliminado'",
    ];

    final filas = await _db.query(
      'recordatorios',
      where: fuera.isEmpty ? null : fuera.join(' AND '),
      orderBy: 'fecha ASC, id ASC',
    );
    return filas.map(Recordatorio.fromRow).toList();
  }

  @override
  Future<List<GrupoRecordatorios>> listarPorMes({
    bool incluirCumplidos = true,
  }) async {
    final items = await listar(incluirCumplidos: incluirCumplidos);
    final grupos = <String, List<Recordatorio>>{};

    for (final item in items) {
      grupos.putIfAbsent(claveMes(item.fecha), () => []).add(item);
    }

    return grupos.entries
        .map((e) => GrupoRecordatorios(e.key, e.value))
        .toList();
  }

  @override
  Future<int> contarVencidos() async {
    final filas = await _db.rawQuery(
        "SELECT COUNT(*) AS n FROM recordatorios WHERE estado = 'vencido'");
    return (filas.first['n'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> crear(Recordatorio recordatorio) {
    final estado = estaVencida(recordatorio.fecha)
        ? EstadoRecordatorio.vencido
        : EstadoRecordatorio.pendiente;

    return _db.insert(
      'recordatorios',
      recordatorio.copyWith(estado: estado).toRow()..remove('id'),
    );
  }

  @override
  Future<int> crearDesdeTrabajo(Trabajo trabajo, Repeticion cada) {
    final fecha =
        cada.siguiente(trabajo.fecha.isEmpty ? hoyISO() : trabajo.fecha);

    return crear(Recordatorio(
      descripcion: trabajo.recomendaciones.trim(),
      fecha: fecha,
      repite: cada,
      origen: OrigenRecordatorio.automatico,
      trabajoId: trabajo.id,
      cliente: trabajo.cliente,
      equipo: trabajo.equipo,
    ));
  }

  @override
  Future<void> actualizar(Recordatorio recordatorio) async {
    if (recordatorio.id == null) return;

    final anterior = await obtener(recordatorio.id!);
    var registro = recordatorio;

    // Reprogramar un vencido para más adelante lo devuelve a pendiente, o
    // seguiría contando en el aviso rojo con una fecha que ya no vencía.
    // Cumplido y eliminado no cambian nunca: son estados finales.
    if (anterior != null) {
      registro = registro.copyWith(
        cumplidoEl: anterior.cumplidoEl,
        eliminadoEl: anterior.eliminadoEl,
        estado: !anterior.activo
            ? anterior.estado
            : estaVencida(registro.fecha)
                ? EstadoRecordatorio.vencido
                : EstadoRecordatorio.pendiente,
      );
    }

    await _db.update('recordatorios', registro.toRow()..remove('id'),
        where: 'id = ?', whereArgs: [registro.id]);
  }

  @override
  Future<void> eliminar(int id) async {
    final actual = await obtener(id);
    if (actual == null || !actual.activo) return;

    await _db.update(
      'recordatorios',
      {
        'estado': EstadoRecordatorio.eliminado.name,
        'eliminadoEl': hoyISO(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int?> eliminarYSeguir(int id) async {
    final actual = await obtener(id);
    if (actual == null || !actual.activo) return null;

    await eliminar(id);
    return actual.seRepite ? _crearSiguiente(actual) : null;
  }

  @override
  Future<void> dejarDeRepetir(int id) async {
    await _db.update(
      'recordatorios',
      {'repetirCada': null, 'repetirUnidad': null, 'repetirMeses': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> borrarParaSiempre(int id) async {
    await _db.delete(
      'recordatorios',
      where: "id = ? AND estado = 'eliminado'",
      whereArgs: [id],
    );
  }

  /// El siguiente cuenta desde la fecha programada, no desde hoy: un
  /// mantenimiento atendido tarde no corre todo el calendario hacia adelante.
  Future<int> _crearSiguiente(Recordatorio actual) => crear(
        actual.copyWith(
          fecha: actual.repite!.siguiente(actual.fecha),
          estado: EstadoRecordatorio.pendiente,
        ),
      );

  @override
  Future<void> marcarImportante(int id, bool importante) async {
    await _db.update(
      'recordatorios',
      {'importante': importante ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int?> marcarCumplido(int id) async {
    final actual = await obtener(id);
    if (actual == null || !actual.activo) return null;

    await _db.update(
      'recordatorios',
      {
        'estado': EstadoRecordatorio.cumplido.name,
        'cumplidoEl': hoyISO(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return actual.seRepite ? _crearSiguiente(actual) : null;
  }

  @override
  Future<int> refrescarVencidos() async {
    return _db.update(
      'recordatorios',
      {'estado': EstadoRecordatorio.vencido.name},
      where: "estado = 'pendiente' AND fecha < ?",
      whereArgs: [hoyISO()],
    );
  }
}
