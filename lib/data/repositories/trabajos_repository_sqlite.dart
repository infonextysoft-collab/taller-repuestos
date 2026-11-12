import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/fechas.dart';
import '../../core/utils/texto.dart';
import '../../domain/entities/foto.dart';
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
    final filas = await _db.query(
      'trabajos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return null;

    // Al abrir un registro sí se traen las fotos completas: se van a ver en el
    // paso de fotos y se van a dibujar en el documento.
    final registro = Trabajo.fromRow(filas.first);
    return registro.copyWith(
      fotosIngreso: await _fotosDe(id, MomentoFoto.ingreso),
      fotosEntrega: await _fotosDe(id, MomentoFoto.entrega),
    );
  }

  /* ----------------------------------------------------------------- fotos */

  Future<List<Foto>> _fotosDe(int trabajoId, MomentoFoto momento) async {
    final filas = await _db.query(
      'fotos',
      where: 'trabajoId = ? AND momento = ?',
      whereArgs: [trabajoId, momento.name],
      orderBy: 'orden ASC, id ASC',
    );
    return filas.map(Foto.fromRow).toList();
  }

  /// La primera foto de ingreso, en chico, para el listado.
  ///
  /// Se pide **solo la columna `mini`**: traer el JPEG completo de cada
  /// registro para dibujar una fila de 50px era cargar decenas de megas para
  /// tirarlos enseguida.
  Future<Map<int, Uint8List>> _miniaturas(List<int> trabajoIds) async {
    if (trabajoIds.isEmpty) return const {};

    final marcas = List.filled(trabajoIds.length, '?').join(',');
    final filas = await _db.rawQuery(
      'SELECT trabajoId, mini, bytes FROM fotos '
      "WHERE momento = 'ingreso' AND trabajoId IN ($marcas) "
      'ORDER BY orden ASC, id ASC',
      trabajoIds,
    );

    final porTrabajo = <int, Uint8List>{};
    for (final fila in filas) {
      final id = (fila['trabajoId'] as num).toInt();
      if (porTrabajo.containsKey(id)) continue;

      final mini = fila['mini'] as Uint8List?;
      final bytes = mini ?? fila['bytes'] as Uint8List?;
      if (bytes != null && bytes.isNotEmpty) porTrabajo[id] = bytes;
    }
    return porTrabajo;
  }

  /// Sincroniza las fotos de un registro con lo que quedó en pantalla.
  ///
  /// Las que ya tienen id **no se reescriben**: se actualiza su orden y nada
  /// más. Reinsertarlas todas en cada guardado significaría volver a escribir
  /// megas de JPEG cada vez que alguien corrige una coma —y, cuando exista el
  /// respaldo, volver a subirlas—.
  Future<List<Foto>> _guardarFotos(
    int trabajoId,
    MomentoFoto momento,
    List<Foto> fotos,
  ) async {
    final vigentes = fotos.map((f) => f.id).whereType<int>().toSet();

    final previas = await _db.query(
      'fotos',
      columns: ['id'],
      where: 'trabajoId = ? AND momento = ?',
      whereArgs: [trabajoId, momento.name],
    );

    for (final fila in previas) {
      final id = (fila['id'] as num).toInt();
      if (!vigentes.contains(id)) {
        await _db.delete('fotos', where: 'id = ?', whereArgs: [id]);
      }
    }

    final guardadas = <Foto>[];
    for (var i = 0; i < fotos.length; i++) {
      final foto = fotos[i];

      if (foto.id == null) {
        final id = await _db.insert('fotos', foto.toRow(trabajoId, momento, i));
        guardadas.add(foto.copyWith(id: id));
      } else {
        await _db.update(
          'fotos',
          {'orden': i},
          where: 'id = ?',
          whereArgs: [foto.id],
        );
        guardadas.add(foto);
      }
    }

    return guardadas;
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
    final encontrados = busqueda.isEmpty
        ? registros.toList()
        : registros
              .where(
                (t) =>
                    coincide(t.cliente, busqueda) ||
                    coincide(t.equipo, busqueda),
              )
              .toList();

    final minis = await _miniaturas(
      encontrados.map((t) => t.id).whereType<int>().toList(),
    );

    return [for (final t in encontrados) t.copyWith(miniatura: minis[t.id])];
  }

  /// Correlativo por tipo y por año: `REP-2026-0001` / `VTA-2026-0001`.
  ///
  /// Se calcula **dentro de la transacción del alta**, o dos registros creados
  /// seguidos se quedan con el mismo número.
  Future<String> _siguienteCodigo(
    DatabaseExecutor txn,
    TipoTrabajo tipo,
    String fecha,
  ) async {
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

  /// Las fotos se guardan fuera de la transacción del alta a propósito: el
  /// alta corre en una transacción por el correlativo, y meter blobs adentro
  /// la alargaría sin necesidad.

  @override
  Future<Trabajo> actualizar(Trabajo trabajo) async {
    // Los totales se recalculan sobre lo que queda guardado, no sobre lo que
    // se mandó: así no dependen del orden de los campos enviados.
    final registro = trabajo.copyWith(
      facturarA: trabajo.aQuienFacturar,
      totales: calculadora.calcular(trabajo),
    );

    await _db.update(
      'trabajos',
      registro.toRow()..remove('id'),
      where: 'id = ?',
      whereArgs: [registro.id],
    );

    return registro.copyWith(
      fotosIngreso: await _guardarFotos(
        registro.id!,
        MomentoFoto.ingreso,
        registro.fotosIngreso,
      ),
      fotosEntrega: await _guardarFotos(
        registro.id!,
        MomentoFoto.entrega,
        registro.fotosEntrega,
      ),
    );
  }

  @override
  Future<Trabajo> guardarPasosHasta(int id, int paso) async {
    final actual = await obtener(id);
    if (actual == null) throw StateError('No existe el registro $id');

    // Marca 1..paso, no solo el último: estar en el paso 6 y guardar no puede
    // perder lo anterior.
    final pasos = {
      ...actual.pasosGuardados,
      for (var p = 1; p <= paso; p++) p,
    }.toList()..sort();

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
  Future<List<Facturado>> facturadosRecientes({
    int limite = 3,
    int? exceptoId,
  }) async {
    final filas = await _db.query(
      'trabajos',
      columns: ['cliente', 'facturarA', 'ruc'],
      where: "TRIM(facturarA) <> ''${exceptoId == null ? '' : ' AND id <> ?'}",
      whereArgs: exceptoId == null ? null : [exceptoId],
      orderBy: 'fecha DESC, id DESC',
    );

    final vistos = <String>{};
    final salida = <Facturado>[];

    for (final fila in filas) {
      final nombre = (fila['facturarA'] ?? '').toString().trim();
      final clave = normalizar(nombre);

      // La venta simple copia el cliente en "Facturar a": eso no es una
      // empresa aparte, es el mismo nombre dos veces.
      if (clave == normalizar(fila['cliente']?.toString())) continue;
      if (!vistos.add(clave)) continue;

      salida.add((nombre: nombre, ruc: (fila['ruc'] ?? '').toString().trim()));
      if (salida.length == limite) break;
    }

    return salida;
  }

  @override
  Future<void> eliminar(int id) async {
    final registro = await obtener(id);
    if (registro == null) return;

    // Borrar el trabajo es borrar todas sus líneas de una vez.
    await _inventario.devolverRepuestos(registro.repuestos);
    // Las fotos no se van solas: no hay claves foráneas en esta base.
    await _db.delete('fotos', where: 'trabajoId = ?', whereArgs: [id]);
    await _db.delete('trabajos', where: 'id = ?', whereArgs: [id]);
  }
}
