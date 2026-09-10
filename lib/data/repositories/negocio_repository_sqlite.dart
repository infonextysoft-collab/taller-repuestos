import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/entities/negocio.dart';
import '../../domain/repositories/negocio_repository.dart';
import '../local/app_database.dart';

/// Datos del emisor sobre SQLite. Siempre la fila `id = 1`.
class NegocioRepositorySqlite implements NegocioRepository {
  NegocioRepositorySqlite(this._base);

  final AppDatabase _base;
  Database get _db => _base.db;

  @override
  Future<Negocio> obtener() async {
    final filas =
        await _db.query('negocio', where: 'id = 1', limit: 1);
    return filas.isEmpty ? const Negocio() : Negocio.fromRow(filas.first);
  }

  @override
  Future<Negocio> guardar(Negocio negocio) async {
    await _db.insert(
      'negocio',
      negocio.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return obtener();
  }
}
