import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/utils/imagenes.dart';
import '../../domain/entities/foto.dart';
import 'fabrica_db.dart';

/// Credenciales iniciales. Se cambian desde la app, en Datos del negocio, no
/// editando este archivo.
const String usuarioInicial = 'Samuel';
const String claveInicial = 'Admin123';

/// Nombre interno del archivo. **No sigue al nombre del negocio**: renombrarlo
/// dejaría huérfanos los datos ya guardados en los celulares donde la app se
/// esté usando. Es un identificador, no una etiqueta que alguien vea.
const String _archivoDb = 'parte.db';

/// La base local: vive en el dispositivo y funciona sin internet.
///
/// Esta clase es la única que sabe que por debajo hay SQLite. Los repos hablan
/// con ella; la interfaz nunca la ve.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase? _instancia;

  /// Abre (y crea la primera vez) la base. Idempotente.
  static Future<AppDatabase> abrir() async {
    if (_instancia != null) return _instancia!;

    // Qué motor usar lo decide `fabrica_db.dart` según la plataforma.
    final base = await fabricaDb().openDatabase(
      await rutaDb(_archivoDb),
      options: OpenDatabaseOptions(version: 1, onCreate: _crear),
    );

    _instancia = AppDatabase._(base);
    await _instancia!._sembrarAuth();
    return _instancia!;
  }

  /// Solo para los tests: base en memoria, sin tocar el disco.
  static Future<AppDatabase> enMemoria() async {
    final base = await fabricaDbMemoria().openDatabase(
      rutaEnMemoria,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: _crear,
        onUpgrade: _actualizar,
      ),
    );
    final instancia = AppDatabase._(base);
    await instancia._sembrarAuth();
    return instancia;
  }

  /// 1 → 2: los recordatorios pasaron de "cada N meses" a un intervalo libre
  /// (N días / semanas / meses / años) y ganaron la marca de importante.
  ///
  /// 2 → 3: las fotos salieron de adentro del registro y pasaron a su propia
  /// tabla, con los bytes crudos en vez de texto base64.
  static const int _version = 3;

  /// Las columnas viejas `recordatorioMeses` y `repetirMeses` **quedan**: son
  /// de dónde lee el intervalo cualquier registro guardado antes de esto, y
  /// borrarlas obligaría a reescribir toda la tabla para no ganar nada.
  static Future<void> _actualizar(Database d, int desde, int hasta) async {
    if (desde < 2) {
      for (final sentencia in const [
        'ALTER TABLE trabajos ADD COLUMN recordatorioCada INTEGER',
        'ALTER TABLE trabajos ADD COLUMN recordatorioUnidad TEXT',
        'ALTER TABLE recordatorios ADD COLUMN repetirCada INTEGER',
        'ALTER TABLE recordatorios ADD COLUMN repetirUnidad TEXT',
        'ALTER TABLE recordatorios ADD COLUMN importante INTEGER NOT NULL '
            'DEFAULT 0',
        "UPDATE trabajos SET recordatorioCada = recordatorioMeses, "
            "recordatorioUnidad = 'meses' WHERE recordatorioMeses IS NOT NULL",
        "UPDATE recordatorios SET repetirCada = repetirMeses, "
            "repetirUnidad = 'meses' WHERE repetirMeses IS NOT NULL",
      ]) {
        await d.execute(sentencia);
      }
    }

    if (desde < 3) {
      await d.execute(_tablaFotos);
      await d.execute(_indiceFotos);
      await _mudarFotos(d);
    }
  }

  /// Saca las fotos de adentro de `trabajos` y las pasa a su tabla.
  ///
  /// Las viejas están como una lista JSON de data URIs. Se decodifican una por
  /// una y se guardan en crudo. Una foto ilegible se descarta en silencio: es
  /// preferible perder una imagen a que la app no abra nunca más.
  @visibleForTesting
  static Future<void> mudarFotos(Database d) => _mudarFotos(d);

  static Future<void> _mudarFotos(Database d) async {
    final filas = await d.query(
      'trabajos',
      columns: ['id', 'fotosIngreso', 'fotosEntrega'],
    );

    for (final fila in filas) {
      final trabajoId = (fila['id'] as num).toInt();

      for (final momento in MomentoFoto.values) {
        final crudo = fila[
            momento == MomentoFoto.ingreso ? 'fotosIngreso' : 'fotosEntrega'];
        final lista = _listaDeTexto(crudo);

        for (var i = 0; i < lista.length; i++) {
          final bytes = bytesDeFoto(lista[i]);
          if (bytes == null || bytes.isEmpty) continue;

          await d.insert('fotos', {
            'trabajoId': trabajoId,
            'momento': momento.name,
            'orden': i,
            'bytes': bytes,
          });
        }
      }

      await d.update(
        'trabajos',
        {'fotosIngreso': '[]', 'fotosEntrega': '[]'},
        where: 'id = ?',
        whereArgs: [trabajoId],
      );
    }
  }

  static List<String> _listaDeTexto(Object? crudo) {
    try {
      final decodificado = jsonDecode((crudo ?? '[]').toString());
      return decodificado is List
          ? decodificado.map((e) => e.toString()).toList()
          : const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _crear(Database d, int version) async {
    for (final sentencia in _esquema) {
      await d.execute(sentencia);
    }
  }

  /// Las fotos, aparte del registro. Ver [Foto] para el porqué.
  ///
  /// `remota` queda desde ya, vacía: es donde va a anotarse la dirección en la
  /// nube cuando exista el respaldo, y agregarla ahora evita otra migración.
  static const String _tablaFotos = '''
    CREATE TABLE fotos (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      trabajoId INTEGER NOT NULL,
      momento   TEXT    NOT NULL,
      orden     INTEGER NOT NULL DEFAULT 0,
      bytes     BLOB    NOT NULL,
      mini      BLOB,
      remota    TEXT
    )
  ''';

  static const String _indiceFotos =
      'CREATE INDEX ix_fotos_trabajo ON fotos(trabajoId, momento, orden)';

  /// El esquema, en el orden en que se crea.
  ///
  /// Van sentencias sueltas y no un batch a propósito: esto corre una sola vez
  /// en la vida de la app, así que la micro-optimización no compensaba —y el
  /// motor de web no devuelve para un lote lo mismo que el nativo—.
  static const List<String> _esquema = [
    '''
      CREATE TABLE trabajos (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo             TEXT    NOT NULL,
        tipo               TEXT    NOT NULL,
        estado             TEXT    NOT NULL,
        fecha              TEXT    NOT NULL,
        cliente            TEXT    NOT NULL DEFAULT '',
        ruc                TEXT    NOT NULL DEFAULT '',
        facturarA          TEXT    NOT NULL DEFAULT '',
        equipo             TEXT    NOT NULL DEFAULT '',
        modelo             TEXT    NOT NULL DEFAULT '',
        ubicacion          TEXT    NOT NULL DEFAULT '',
        movilidad          TEXT    NOT NULL DEFAULT 'cliente',
        vueltas            INTEGER NOT NULL DEFAULT 0,
        precioVuelta       REAL    NOT NULL DEFAULT 0,
        cobraTraslado      INTEGER NOT NULL DEFAULT 0,
        fotosIngreso       TEXT    NOT NULL DEFAULT '[]',
        fotosEntrega       TEXT    NOT NULL DEFAULT '[]',
        observaciones      TEXT    NOT NULL DEFAULT '',
        diagnostico        TEXT    NOT NULL DEFAULT '',
        trabajosRealizados TEXT    NOT NULL DEFAULT '[]',
        repuestos          TEXT    NOT NULL DEFAULT '[]',
        recomendaciones    TEXT    NOT NULL DEFAULT '',
        recordatorioMeses  INTEGER,
        recordatorioCada   INTEGER,
        recordatorioUnidad TEXT,
        descuento          REAL    NOT NULL DEFAULT 0,
        vistaDoc           TEXT    NOT NULL DEFAULT 'junto',
        totales            TEXT    NOT NULL DEFAULT '{}',
        pasosGuardados     TEXT    NOT NULL DEFAULT '[]'
      )
    ''',
    'CREATE INDEX ix_trabajos_codigo ON trabajos(codigo)',
    'CREATE INDEX ix_trabajos_tipo   ON trabajos(tipo)',
    'CREATE INDEX ix_trabajos_estado ON trabajos(estado)',
    'CREATE INDEX ix_trabajos_fecha  ON trabajos(fecha)',
    '''
      CREATE TABLE inventario (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre       TEXT    NOT NULL,
        stock        INTEGER NOT NULL DEFAULT 0,
        precio       REAL    NOT NULL DEFAULT 0,
        codigoBarras TEXT
      )
    ''',
    'CREATE INDEX ix_inventario_nombre ON inventario(nombre)',
    // UNIQUE deja pasar varios NULL: por eso un código vacío se guarda como
    // NULL y no como cadena vacía.
    'CREATE UNIQUE INDEX ix_inventario_codigo ON inventario(codigoBarras)',
    '''
      CREATE TABLE recordatorios (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion  TEXT    NOT NULL DEFAULT '',
        fecha        TEXT    NOT NULL,
        repetirMeses INTEGER,
        repetirCada  INTEGER,
        repetirUnidad TEXT,
        estado       TEXT    NOT NULL DEFAULT 'pendiente',
        origen       TEXT    NOT NULL DEFAULT 'manual',
        importante   INTEGER NOT NULL DEFAULT 0,
        trabajoId    INTEGER,
        cliente      TEXT,
        equipo       TEXT
      )
    ''',
    'CREATE INDEX ix_rec_fecha   ON recordatorios(fecha)',
    'CREATE INDEX ix_rec_estado  ON recordatorios(estado)',
    'CREATE INDEX ix_rec_trabajo ON recordatorios(trabajoId)',
    _tablaFotos,
    _indiceFotos,
    '''
      CREATE TABLE negocio (
        id        INTEGER PRIMARY KEY,
        nombre    TEXT NOT NULL DEFAULT '',
        ruc       TEXT NOT NULL DEFAULT '',
        direccion TEXT NOT NULL DEFAULT '',
        telefono  TEXT NOT NULL DEFAULT '',
        email     TEXT NOT NULL DEFAULT ''
      )
    ''',
    '''
      CREATE TABLE auth (
        id      INTEGER PRIMARY KEY,
        usuario TEXT NOT NULL,
        clave   TEXT NOT NULL
      )
    ''',
  ];

  /// Siembra el usuario por defecto **solo** la primera vez: nunca pisa una
  /// clave que el usuario ya cambió.
  Future<void> _sembrarAuth() async {
    final existente = await db.query('auth', where: 'id = 1', limit: 1);
    if (existente.isEmpty) {
      await db.insert('auth', {
        'id': 1,
        'usuario': usuarioInicial,
        'clave': claveInicial,
      });
    }
  }

  Future<void> cerrar() async {
    await db.close();
    _instancia = null;
  }
}
