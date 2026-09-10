import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/texto.dart';
import '../../domain/entities/linea.dart';
import '../../domain/entities/repuesto.dart';
import '../../domain/repositories/inventario_repository.dart';
import '../local/app_database.dart';

/// Inventario sobre SQLite, más la lógica de stock ↔ líneas de repuesto.
class InventarioRepositorySqlite implements InventarioRepository {
  InventarioRepositorySqlite(this._base);

  final AppDatabase _base;
  Database get _db => _base.db;

  @override
  Future<List<Repuesto>> listar() async {
    final filas = await _db.query('inventario');
    final items = filas.map(Repuesto.fromRow).toList();
    // Orden alfabético con las tildes en su lugar: SQLite no sabe de español.
    items.sort((a, b) => normalizar(a.nombre).compareTo(normalizar(b.nombre)));
    return items;
  }

  @override
  Future<Repuesto?> obtener(int id) async {
    final filas =
        await _db.query('inventario', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Repuesto.fromRow(filas.first);
  }

  @override
  Future<Repuesto?> buscarPorCodigo(String? codigo) async {
    final c = normalizarCodigo(codigo);
    if (c == null) return null;
    final filas = await _db
        .query('inventario', where: 'codigoBarras = ?', whereArgs: [c], limit: 1);
    return filas.isEmpty ? null : Repuesto.fromRow(filas.first);
  }

  @override
  Future<Repuesto?> porNombreExacto(String nombre) async {
    final buscado = normalizar(nombre);
    if (buscado.isEmpty) return null;
    for (final item in await listar()) {
      if (normalizar(item.nombre) == buscado) return item;
    }
    return null;
  }

  @override
  Future<bool> codigoRepetido(String? codigo, {int? exceptoId}) async {
    final encontrado = await buscarPorCodigo(codigo);
    if (encontrado == null) return false;
    return encontrado.id != exceptoId;
  }

  @override
  Future<int> crear(Repuesto repuesto) =>
      _db.insert('inventario', repuesto.toRow()..remove('id'));

  @override
  Future<void> actualizar(Repuesto repuesto) async {
    if (repuesto.id == null) return;
    await _db.update('inventario', repuesto.toRow()..remove('id'),
        where: 'id = ?', whereArgs: [repuesto.id]);
  }

  @override
  Future<void> eliminar(int id) async {
    await _db.delete('inventario', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> sumarStock(int id, int cantidad) async {
    await _db.rawUpdate(
      'UPDATE inventario SET stock = MAX(0, stock + ?) WHERE id = ?',
      [cantidad, id],
    );
  }

  @override
  Future<ResultadoLineas> agregarRepuesto({
    int? inventarioId,
    required String desc,
    required int cant,
    double? precio,
  }) async {
    final cantidad = cant < 0 ? 0 : cant;

    if (inventarioId == null || cantidad == 0) {
      return ResultadoLineas([_externa(desc, cantidad, precio ?? 0)]);
    }

    return _db.transaction((txn) async {
      final filas = await txn.query('inventario',
          where: 'id = ?', whereArgs: [inventarioId], limit: 1);

      // El repuesto se borró del inventario mientras estaba abierto el selector.
      if (filas.isEmpty) {
        return ResultadoLineas([_externa(desc, cantidad, precio ?? 0)]);
      }

      final item = Repuesto.fromRow(filas.first);
      final disponible = item.stock < 0 ? 0 : item.stock;
      final deInventario = cantidad < disponible ? cantidad : disponible;
      final externo = cantidad - deInventario;
      final precioLinea = precio ?? item.precio;

      final lineas = <LineaRepuesto>[];

      if (deInventario > 0) {
        await txn.update('inventario', {'stock': disponible - deInventario},
            where: 'id = ?', whereArgs: [item.id]);
        lineas.add(LineaRepuesto(
          desc: item.nombre,
          cantidad: deInventario,
          precio: precioLinea,
          origen: OrigenRepuesto.inventario,
          inventarioId: item.id,
        ));
      }

      if (externo > 0) {
        lineas.add(_externa(item.nombre, externo, precioLinea));
      }

      final aviso = externo == 0
          ? null
          : disponible == 0
              ? '"${item.nombre}" está agotado. Las $externo unidades se '
                  'registraron como repuesto externo.'
              : 'Solo había $disponible de "${item.nombre}" en inventario. '
                  'Las otras $externo se registraron como repuesto externo.';

      return ResultadoLineas(lineas, aviso);
    });
  }

  @override
  Future<void> devolverRepuesto(LineaRepuesto linea) async {
    if (!linea.esDeInventario) return;
    // Si el repuesto ya no existe no hay a dónde devolverlo: no es un error.
    await sumarStock(linea.inventarioId!, linea.cantidad);
  }

  @override
  Future<void> devolverRepuestos(List<LineaRepuesto> lineas) async {
    for (final linea in lineas) {
      await devolverRepuesto(linea);
    }
  }

  @override
  Future<void> retomarRepuesto(LineaRepuesto linea) async {
    if (!linea.esDeInventario) return;
    await sumarStock(linea.inventarioId!, -linea.cantidad);
  }

  @override
  Future<void> restaurarRepuestos(
    List<LineaRepuesto> actuales,
    List<LineaRepuesto> originales,
  ) async {
    for (final linea in actuales) {
      await devolverRepuesto(linea);
    }
    for (final linea in originales) {
      await retomarRepuesto(linea);
    }
  }

  LineaRepuesto _externa(String desc, int cant, double precio) => LineaRepuesto(
        desc: desc.trim(),
        cantidad: cant,
        precio: precio,
      );
}
