import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/texto.dart';
import '../../domain/entities/compra.dart';
import '../../domain/repositories/compras_repository.dart';
import '../local/app_database.dart';

/// Compras sobre SQLite.
class ComprasRepositorySqlite implements ComprasRepository {
  ComprasRepositorySqlite(this._base);

  final AppDatabase _base;
  Database get _db => _base.db;

  @override
  Future<List<Compra>> listar({int? limite}) async {
    final filas = await _db.query(
      'compras',
      orderBy: 'fecha DESC, id DESC',
      limit: limite,
    );
    return filas.map(Compra.fromRow).toList();
  }

  @override
  Future<List<Compra>> deRepuesto(int inventarioId, {int limite = 3}) async {
    // El renglón vive dentro del JSON, así que el filtro es en Dart. Con las
    // compras de un taller esto es una lista corta; si algún día no lo fuera,
    // el arreglo es una tabla de renglones, no un LIKE sobre el JSON.
    final todas = await listar();
    return todas
        .where((c) => c.lineas.any((l) => l.inventarioId == inventarioId))
        .take(limite)
        .toList();
  }

  @override
  Future<Compra> registrar(Compra compra) async {
    final id = await _db.transaction((txn) async {
      final nuevo = await txn.insert('compras', compra.toRow()..remove('id'));

      for (final linea in compra.lineas) {
        final repuestoId = linea.inventarioId;
        if (repuestoId == null || linea.cantidad <= 0) continue;

        // El precio de compra queda en el último pagado: es lo que el taller
        // entiende por "me cuesta". El promedio ponderado sería más fiel a la
        // contabilidad y menos a la cabeza de quien lo usa.
        await txn.rawUpdate(
          'UPDATE inventario SET stock = stock + ?, precioCosto = ? '
          'WHERE id = ?',
          [linea.cantidad, linea.costo, repuestoId],
        );
      }

      return nuevo;
    });

    final filas =
        await _db.query('compras', where: 'id = ?', whereArgs: [id], limit: 1);
    return Compra.fromRow(filas.first);
  }

  @override
  Future<void> eliminar(int id) async {
    final filas =
        await _db.query('compras', where: 'id = ?', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return;

    final compra = Compra.fromRow(filas.first);

    await _db.transaction((txn) async {
      for (final linea in compra.lineas) {
        final repuestoId = linea.inventarioId;
        if (repuestoId == null || linea.cantidad <= 0) continue;

        // Nunca por debajo de cero: si ya se vendió parte de lo que entró con
        // esta compra, el stock real es el que hay, no un número negativo.
        await txn.rawUpdate(
          'UPDATE inventario SET stock = MAX(0, stock - ?) WHERE id = ?',
          [linea.cantidad, repuestoId],
        );
      }

      await txn.delete('compras', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<String>> proveedoresFrecuentes({int limite = 4}) async {
    final filas = await _db.query(
      'compras',
      columns: ['proveedor'],
      orderBy: 'fecha DESC, id DESC',
    );

    // Se agrupa ignorando tildes y mayúsculas —"Repuestos Lima" y "repuestos
    // lima" son el mismo—, y se muestra la forma más reciente, que es como la
    // escribió la última vez.
    final cuenta = <String, int>{};
    final comoSeEscribe = <String, String>{};

    for (final fila in filas) {
      final nombre = (fila['proveedor'] ?? '').toString().trim();
      if (nombre.isEmpty) continue;

      final clave = normalizar(nombre);
      cuenta[clave] = (cuenta[clave] ?? 0) + 1;
      comoSeEscribe.putIfAbsent(clave, () => nombre);
    }

    final claves = cuenta.keys.toList()
      ..sort((a, b) => cuenta[b]!.compareTo(cuenta[a]!));

    return [for (final c in claves.take(limite)) comoSeEscribe[c]!];
  }
}
