import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/utils/fechas.dart';
import '../../domain/repositories/respaldo_repository.dart';
import '../local/app_database.dart';

/// El respaldo, como un ZIP.
///
/// Adentro van dos cosas:
///
///   - `datos.json` — las filas de cada tabla, tal cual. No se traduce a
///     entidades a propósito: si mañana se agrega una columna, el respaldo la
///     lleva sin que haya que tocar esto.
///   - `fotos/<id>.jpg` — cada imagen como archivo, **en crudo**. Meterlas
///     dentro del JSON obligaría a convertirlas a texto y el archivo crecería
///     un tercio sin ganar nada.
///
/// Es ZIP y no una copia de la base porque un ZIP se puede abrir y mirar: si
/// algún día algo sale mal, los datos se rescatan con el explorador de
/// archivos y sin esta app.
class RespaldoZip implements RespaldoRepository {
  RespaldoZip(this._base);

  final AppDatabase _base;
  Database get _db => _base.db;

  /// Las tablas que se copian, en orden de restauración.
  static const List<String> _tablas = [
    'negocio',
    'inventario',
    'trabajos',
    'recordatorios',
  ];

  static const String _archivoDatos = 'datos.json';
  static const String _carpetaFotos = 'fotos';

  /// Sube cuando cambia la forma del respaldo, no el esquema de la base.
  /// La 2 sumó las compras, que después se sacaron de la app. El número no
  /// vuelve atrás: un respaldo hecho con la 2 se restaura igual, y su clave
  /// `compras` simplemente ya no le interesa a nadie.
  static const int _formato = 2;

  /* ------------------------------------------------------------- exportar */

  @override
  Future<Uint8List> exportar() async {
    final zip = Archive();
    final datos = <String, Object?>{
      'formato': _formato,
      'esquema': await _db.getVersion(),
      'fecha': hoyISO(),
    };

    for (final tabla in _tablas) {
      datos[tabla] = await _db.query(tabla);
    }

    // Las fotos salen del JSON: en el JSON va su ficha, los bytes van al ZIP.
    final fichas = <Map<String, Object?>>[];
    for (final fila in await _db.query('fotos')) {
      final id = (fila['id'] as num).toInt();

      fichas.add({
        for (final campo in fila.keys)
          if (campo != 'bytes' && campo != 'mini') campo: fila[campo],
      });

      _guardar(zip, '$_carpetaFotos/$id.jpg', fila['bytes']);
      _guardar(zip, '$_carpetaFotos/$id-mini.jpg', fila['mini']);
    }
    datos['fotos'] = fichas;

    zip.addFile(ArchiveFile.bytes(
      _archivoDatos,
      utf8.encode(jsonEncode(datos)),
    ));

    final bytes = ZipEncoder().encode(zip);
    return Uint8List.fromList(bytes);
  }

  void _guardar(Archive zip, String nombre, Object? bytes) {
    if (bytes is! Uint8List || bytes.isEmpty) return;
    zip.addFile(ArchiveFile.bytes(nombre, bytes));
  }

  /* ------------------------------------------------------------ restaurar */

  @override
  Future<ResumenRespaldo> restaurar(Uint8List archivo) async {
    final zip = _abrir(archivo);

    final crudo = zip.findFile(_archivoDatos);
    if (crudo == null) {
      throw const RespaldoInvalido(
        'Ese archivo no es un respaldo de la app: le falta datos.json.',
      );
    }

    final Map<String, Object?> datos;
    try {
      datos = Map<String, Object?>.from(
        jsonDecode(utf8.decode(crudo.readBytes()!)) as Map,
      );
    } catch (_) {
      throw const RespaldoInvalido('El respaldo está dañado y no se puede leer.');
    }

    final formato = (datos['formato'] as num?)?.toInt() ?? 0;
    if (formato > _formato) {
      throw const RespaldoInvalido(
        'Ese respaldo lo hizo una versión más nueva de la app. Actualiza la app '
        'y vuelve a intentar.',
      );
    }

    // Se borra todo antes de escribir: restaurar es volver a un momento, no
    // mezclar dos historiales.
    await _db.transaction((txn) async {
      await txn.delete('fotos');
      for (final tabla in _tablas.reversed) {
        await txn.delete(tabla);
      }

      for (final tabla in _tablas) {
        for (final fila in _filas(datos[tabla])) {
          await txn.insert(tabla, fila,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final ficha in _filas(datos['fotos'])) {
        final id = (ficha['id'] as num?)?.toInt();
        if (id == null) continue;

        final bytes = _leer(zip, '$_carpetaFotos/$id.jpg');
        // Una foto cuyo archivo no vino es una foto que no existe: guardar la
        // ficha sin imagen dejaría un hueco roto en el documento.
        if (bytes == null) continue;

        await txn.insert(
          'fotos',
          {...ficha, 'bytes': bytes, 'mini': _leer(zip, '$_carpetaFotos/$id-mini.jpg')},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return ResumenRespaldo(
      trabajos: _filas(datos['trabajos']).length,
      repuestos: _filas(datos['inventario']).length,
      recordatorios: _filas(datos['recordatorios']).length,
      fotos: (await _db.query('fotos')).length,
      fecha: (datos['fecha'] ?? '').toString(),
    );
  }

  Archive _abrir(Uint8List archivo) {
    try {
      return ZipDecoder().decodeBytes(archivo);
    } catch (_) {
      throw const RespaldoInvalido(
        'No se pudo abrir el archivo. ¿Seguro que es el respaldo?',
      );
    }
  }

  Uint8List? _leer(Archive zip, String nombre) {
    final archivo = zip.findFile(nombre);
    final bytes = archivo?.readBytes();
    return bytes == null || bytes.isEmpty ? null : Uint8List.fromList(bytes);
  }

  List<Map<String, Object?>> _filas(Object? crudo) {
    if (crudo is! List) return const [];
    return crudo
        .whereType<Map>()
        .map((m) => Map<String, Object?>.from(m))
        .toList();
  }

  /* -------------------------------------------------------------- resumen */

  @override
  Future<ResumenRespaldo> resumenActual() async => ResumenRespaldo(
        trabajos: await _contar('trabajos'),
        repuestos: await _contar('inventario'),
        recordatorios: await _contar('recordatorios'),
        fotos: await _contar('fotos'),
      );

  Future<int> _contar(String tabla) async {
    final filas = await _db.rawQuery('SELECT COUNT(*) AS n FROM $tabla');
    return (filas.first['n'] as num?)?.toInt() ?? 0;
  }
}
