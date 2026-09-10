import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/fechas.dart';
import '../../core/utils/texto.dart';
import '../../domain/entities/trabajo.dart';
import '../../domain/repositories/inventario_repository.dart';
import '../../domain/repositories/trabajos_repository.dart';
import '../../domain/services/calculadora_totales.dart';
import '../local/app_database.dart';

/// Ventas y trabajos sobre SQLite.
class TrabajosRepositorySqlite implements TrabajosRepository {
  TrabajosRepositorySqlite(this._base, this._inventario);

  final AppDatabase _base;
  final InventarioRepository _inventario;

  Database get _db => _base.db;

  @override
  Future<Trabajo?> obtener(int id) async {
    final filas =
        await _db.query('trabajos', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Trabajo.fromRow(filas.first);
  }

  @override
  Future<List<Trabajo>> listar([
    FiltroHistorial filtro = const FiltroHistorial(),
  ]) async {
    final condiciones = <String>[];
    final argumentos = <Object?>[];

    if (filtro.desde.isNotEmpty) {
      condiciones.add('fecha >= ?');
      argumentos.add(filtro.desde);
    }
    if (filtro.hasta.isNotEmpty) {
      condiciones.add('fecha <= ?');
      argumentos.add(filtro.hasta);
    }
    if (filtro.tipo != null) {
      condiciones.add('tipo = ?');
      argumentos.add(filtro.tipo!.name);
    }

    final filas = await _db.query(
      'trabajos',
      where: condiciones.isEmpty ? null : condiciones.join(' AND '),
      whereArgs: argumentos.isEmpty ? null : argumentos,
      // Más reciente primero; a igual fecha, el último registrado arriba.
      orderBy: 'fecha DESC, id DESC',
    );

    final registros = filas.map(Trabajo.fromRow);

    // La búsqueda por texto se filtra acá y no en SQL: mira cliente y equipo,
    // e ignora tildes y mayúsculas, que es lo que espera quien escribe rápido.
    final busqueda = filtro.busqueda.trim();
    if (busqueda.isEmpty) return registros.toList();

    return registros
        .where((t) => coincide(t.cliente, busqueda) || coincide(t.equipo, busqueda))
        .toList();
  }

  /// Correlativo por tipo y por año: `REP-2026-0001` / `VTA-2026-0001`.
  ///
  /// Se calcula **dentro de la transacción del alta**, o dos registros creados
  /// seguidos se quedan con el mismo número.
  Future<String> _siguienteCodigo(
      DatabaseExecutor txn, TipoTrabajo tipo, String fecha) async {
    final anio = (fecha.isEmpty ? hoyISO() : fecha).substring(0, 4);
    final inicio = '${tipo.prefijoCodigo}-$anio-';

    final filas = await txn.query(
      'trabajos',
      columns: ['codigo'],
      where: 'codigo LIKE ?',
      whereArgs: ['$inicio%'],
      orderBy: 'codigo DESC',
      limit: 1,
    );

    final correlativo = filas.isEmpty
        ? 1
        : (int.tryParse(
                  filas.first['codigo'].toString().substring(inicio.length),
                ) ??
                0) +
            1;

    return '$inicio${correlativo.toString().padLeft(4, '0')}';
  }

  @override
  Future<Trabajo> crear(Trabajo borrador) async {
    final fecha = borrador.fecha.isEmpty ? hoyISO() : borrador.fecha;

    return _db.transaction((txn) async {
      final codigo = await _siguienteCodigo(txn, borrador.tipo, fecha);

      var registro = borrador.copyWith(
        codigo: codigo,
        fecha: fecha,
        estado: EstadoTrabajo.pendiente,
        facturarA: borrador.aQuienFacturar,
      );
      registro = registro.copyWith(totales: calculadora.calcular(registro));

      final id = await txn.insert('trabajos', registro.toRow()..remove('id'));
      return registro.copyWith(id: id);
    });
  }

  @override
  Future<Trabajo> actualizar(Trabajo trabajo) async {
    // Los totales se recalculan sobre lo que queda guardado, no sobre lo que
    // se mandó: así no dependen del orden de los campos enviados.
    final registro = trabajo.copyWith(
      facturarA: trabajo.aQuienFacturar,
      totales: calculadora.calcular(trabajo),
    );

    await _db.update('trabajos', registro.toRow()..remove('id'),
        where: 'id = ?', whereArgs: [registro.id]);

    return registro;
  }

  @override
  Future<Trabajo> guardarPasosHasta(int id, int paso) async {
    final actual = await obtener(id);
    if (actual == null) throw StateError('No existe el registro $id');

    // Marca 1..paso, no solo el último: estar en el paso 6 y guardar no puede
    // perder lo anterior.
    final pasos = {...actual.pasosGuardados, for (var p = 1; p <= paso; p++) p}
        .toList()
      ..sort();

    return actualizar(actual.copyWith(pasosGuardados: pasos));
  }

  @override
  Future<Trabajo> editarPaso(int id, int paso) async {
    final actual = await obtener(id);
    if (actual == null) throw StateError('No existe el registro $id');

    final pasos = actual.pasosGuardados.where((p) => p != paso).toList();
    return actualizar(actual.copyWith(pasosGuardados: pasos));
  }

  @override
  Future<Trabajo> terminar(int id) async {
    final actual = await obtener(id);
    if (actual == null) throw StateError('No existe el registro $id');
    return actualizar(actual.copyWith(estado: EstadoTrabajo.terminado));
  }

  @override
  Future<void> eliminar(int id) async {
    final registro = await obtener(id);
    if (registro == null) return;

    // Borrar el trabajo es borrar todas sus líneas de una vez.
    await _inventario.devolverRepuestos(registro.repuestos);
    await _db.delete('trabajos', where: 'id = ?', whereArgs: [id]);
  }
}
