import 'package:sqflite_common/sqlite_api.dart';

import '../../core/config/negocio_fijo.dart';
import '../../domain/entities/negocio.dart';
import '../../domain/repositories/negocio_repository.dart';
import '../local/app_database.dart';

/// Datos del emisor sobre SQLite. Siempre la fila `id = 1`.
class NegocioRepositorySqlite implements NegocioRepository {
  NegocioRepositorySqlite(this._base, {this.rucFijo = kRucFijo});

  final AppDatabase _base;

  /// Vacío si esta instalación no trae uno fijo.
  final String rucFijo;
  Database get _db => _base.db;

  /// Con RUC fijo manda ese, aunque en la base o en un respaldo restaurado
  /// haya otro: la fila guardada no puede cambiarlo.
  @override
  Future<Negocio> obtener() async {
    final filas = await _db.query('negocio', where: 'id = 1', limit: 1);
    final negocio = filas.isEmpty
        ? const Negocio()
        : Negocio.fromRow(filas.first);
    return rucFijo.isEmpty ? negocio : negocio.copyWith(ruc: rucFijo);
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
