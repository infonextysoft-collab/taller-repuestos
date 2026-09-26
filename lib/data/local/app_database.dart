import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, kIsWeb, visibleForTesting;

import '../../core/utils/clave_segura.dart';
import '../../core/utils/imagenes.dart';
import '../../domain/entities/foto.dart';
import 'fabrica_db.dart';

/// Credenciales iniciales. Se cambian desde la app, en Datos del negocio, no
/// editando este archivo.
const String usuarioInicial = 'Samuel';
const String claveInicial = 'Admin123';

/// Cuántas vueltas lleva una huella nueva en esta plataforma. Una sola fuente
/// para la migración y para el acceso: si se separan, la web termina trabando
/// la pestaña con el costo pensado para el celular.
int get vueltasClave => kIsWeb ? kVueltasClaveWeb : kVueltasClave;

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
    _instancia = await abrirEn(fabricaDb(), await rutaDb(_archivoDb));
    return _instancia!;
  }

  /// Solo para los tests: base en memoria, sin tocar el disco.
  static Future<AppDatabase> enMemoria() =>
      abrirEn(fabricaDbMemoria(), rutaEnMemoria);

  /// Abre la base de un archivo concreto.
  ///
  /// Es el único camino, tanto para el teléfono como para los tests: queda
  /// aparte de [abrir] para poder probar la apertura sobre copias de bases
  /// viejas de verdad.
  @visibleForTesting
  static Future<AppDatabase> abrirEn(DatabaseFactory fabrica, String ruta) async {
    final base = await fabrica.openDatabase(ruta, options: _opciones);
    final instancia = AppDatabase._(base);
    await instancia._sembrarAuth();
    return instancia;
  }

  /// Las mismas opciones en el teléfono y en los tests.
  ///
  /// Hasta la versión 4 no lo eran: el teléfono abría la base como "versión 1"
  /// y sin migraciones, así que las migraciones solo corrían en los tests. Una
  /// instalación nueva salía bien —la base se crea con el esquema completo—,
  /// pero una base ya existente nunca recibía las tablas nuevas.
  static OpenDatabaseOptions get _opciones => OpenDatabaseOptions(
        version: _version,
        onCreate: _crear,
        onUpgrade: _actualizar,
      );

  /// 1 → 2: los recordatorios pasaron de "cada N meses" a un intervalo libre
  /// (N días / semanas / meses / años) y ganaron la marca de importante.
  ///
  /// 2 → 3: las fotos salieron de adentro del registro y pasaron a su propia
  /// tabla, con los bytes crudos en vez de texto base64.
  ///
  /// 3 → 4: la contraseña deja de guardarse tal cual —queda su huella— y la
  /// tabla gana el correo con el que se recupera.
  ///
  /// 4 → 5: el negocio guarda con qué le pagan —banco, cuenta, CCI, Yape—
  /// para que salga al pie de la boleta.
  ///
  /// 5 → 6: el repuesto guarda a cuánto se compra, no solo a cuánto se vende.
  /// Sin eso no hay forma de saber cuánto se gana.
  ///
  /// 6 → 7: aparecieron las compras como tabla propia. **Se dio marcha
  /// atrás en la 8**: registrar cada compra con proveedor, boleta y renglones
  /// era demasiado trámite para un taller, y lo único que se quería saber
  /// —de quién se compra un repuesto— entra en el repuesto mismo. La tabla
  /// se deja de crear y de usar; en las bases que ya la tienen queda vacía,
  /// que es más barato que borrarla y no se lleva nada puesto.
  ///
  /// 7 → 8: el trabajo guarda placa, año, número de motor y VIN, y el
  /// repuesto de quién se compra.
  static const int _version = 8;

  @visibleForTesting
  static int get version => _version;

  /// Cada paso **mira antes de tocar**.
  ///
  /// Como el teléfono abría todo como "versión 1" (ver [_opciones]), hay bases
  /// que dicen 1 y ya traen casi todo adentro: la de la vista web tiene las
  /// columnas de la v2 pero no la tabla de fotos, y la del primer APK tiene
  /// todo hasta la v3. Agregar una columna que ya existe revienta la apertura,
  /// y con ella la app entera, así que nada se agrega sin fijarse primero.
  ///
  /// sqflite corre esto dentro de una transacción: si algo falla a la mitad,
  /// la base queda como estaba y no a medio migrar.
  ///
  /// Las columnas viejas `recordatorioMeses` y `repetirMeses` **quedan**: son
  /// de dónde lee el intervalo cualquier registro guardado antes de esto, y
  /// borrarlas obligaría a reescribir toda la tabla para no ganar nada.
  static Future<void> _actualizar(Database d, int desde, int hasta) async {
    if (desde < 2) {
      final nuevoEnTrabajos =
          await _agregarColumna(d, 'trabajos', 'recordatorioCada', 'INTEGER');
      await _agregarColumna(d, 'trabajos', 'recordatorioUnidad', 'TEXT');

      final nuevoEnRecordatorios =
          await _agregarColumna(d, 'recordatorios', 'repetirCada', 'INTEGER');
      await _agregarColumna(d, 'recordatorios', 'repetirUnidad', 'TEXT');
      await _agregarColumna(
          d, 'recordatorios', 'importante', 'INTEGER NOT NULL DEFAULT 0');

      // El intervalo viejo se copia solo donde la columna recién nace. En una
      // base que ya la tenía, lo que hay adentro es lo bueno: pisarlo
      // convertiría un "cada 15 días" en meses.
      if (nuevoEnTrabajos) {
        await d.execute(
          "UPDATE trabajos SET recordatorioCada = recordatorioMeses, "
          "recordatorioUnidad = 'meses' WHERE recordatorioMeses IS NOT NULL",
        );
      }
      if (nuevoEnRecordatorios) {
        await d.execute(
          "UPDATE recordatorios SET repetirCada = repetirMeses, "
          "repetirUnidad = 'meses' WHERE repetirMeses IS NOT NULL",
        );
      }
    }

    // Si la tabla ya existe, las fotos ya viven ahí: no hay nada que mudar.
    if (desde < 3 && !await _existeTabla(d, 'fotos')) {
      await d.execute(_tablaFotos);
      await d.execute(_indiceFotos);
      await _mudarFotos(d);
    }

    if (desde < 4) {
      await _agregarColumna(d, 'auth', 'correo', 'TEXT');
      await _agregarColumna(d, 'auth', 'claveHuella', 'TEXT');
      await _agregarColumna(d, 'auth', 'claveSal', 'TEXT');
      await _agregarColumna(d, 'auth', 'claveVueltas', 'INTEGER');
      await _protegerClaves(d);
    }

    if (desde < 5) {
      const vacia = "TEXT NOT NULL DEFAULT ''";
      await _agregarColumna(d, 'negocio', 'banco', vacia);
      await _agregarColumna(d, 'negocio', 'cuenta', vacia);
      await _agregarColumna(d, 'negocio', 'cci', vacia);
      await _agregarColumna(d, 'negocio', 'yape', vacia);
    }

    if (desde < 6) {
      await _agregarColumna(
          d, 'inventario', 'precioCosto', 'REAL NOT NULL DEFAULT 0');
    }

    // La 7 creaba la tabla `compras`. Ya no: ver la historia de [_version].

    if (desde < 8) {
      const vacia = "TEXT NOT NULL DEFAULT ''";
      await _agregarColumna(d, 'trabajos', 'placa', vacia);
      await _agregarColumna(d, 'trabajos', 'anio', vacia);
      await _agregarColumna(d, 'trabajos', 'nMotor', vacia);
      await _agregarColumna(d, 'trabajos', 'vin', vacia);
      await _agregarColumna(d, 'inventario', 'proveedor', vacia);
    }
  }

  @visibleForTesting
  static Future<void> actualizar(Database d, int desde, int hasta) =>
      _actualizar(d, desde, hasta);

  /// Agrega la columna si falta. Devuelve si la tuvo que agregar.
  static Future<bool> _agregarColumna(
    Database d,
    String tabla,
    String columna,
    String tipo,
  ) async {
    final columnas = await d.rawQuery('PRAGMA table_info($tabla)');
    if (columnas.any((c) => c['name'] == columna)) return false;

    await d.execute('ALTER TABLE $tabla ADD COLUMN $columna $tipo');
    return true;
  }

  static Future<bool> _existeTabla(Database d, String tabla) async {
    final filas = await d.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tabla],
    );
    return filas.isNotEmpty;
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

  /// Deja de guardar la contraseña tal cual.
  ///
  /// La de fábrica **no** se convierte en huella: está escrita en el README, no
  /// es un secreto, y "sin huella" es justamente como se reconoce que nadie la
  /// cambió. Cualquier otra pasa a huella y el texto se borra.
  @visibleForTesting
  static Future<void> protegerClaves(Database d) => _protegerClaves(d);

  static Future<void> _protegerClaves(Database d) async {
    final filas = await d.query(
      'auth',
      columns: ['id', 'clave'],
      where: 'claveHuella IS NULL',
    );

    for (final fila in filas) {
      final clave = (fila['clave'] ?? '').toString();
      final cambios = <String, Object?>{'clave': ''};

      if (clave.isNotEmpty && clave != claveInicial) {
        // Fuera del hilo principal: esto corre antes del primer cuadro, con
        // la pantalla de arranque del sistema a la vista.
        final huella = await compute(_huellaDe, (clave, vueltasClave));
        cambios
          ..['claveHuella'] = huella.huella
          ..['claveSal'] = huella.sal
          ..['claveVueltas'] = huella.vueltas;
      }

      await d.update('auth', cambios, where: 'id = ?', whereArgs: [fila['id']]);
    }
  }

  static HuellaClave _huellaDe((String, int) datos) =>
      HuellaClave.de(datos.$1, vueltas: datos.$2);

  static Future<void> _crear(Database d, int version) async {
    for (final sentencia in _esquema) {
      await d.execute(sentencia);
    }
  }

  /// El esquema actual completo, como lo recibe una instalación nueva.
  @visibleForTesting
  static Future<void> crearEsquema(Database d) => _crear(d, _version);

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
        placa              TEXT    NOT NULL DEFAULT '',
        anio               TEXT    NOT NULL DEFAULT '',
        nMotor             TEXT    NOT NULL DEFAULT '',
        vin                TEXT    NOT NULL DEFAULT '',
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
        precioCosto  REAL    NOT NULL DEFAULT 0,
        proveedor    TEXT    NOT NULL DEFAULT '',
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
        email     TEXT NOT NULL DEFAULT '',
        banco     TEXT NOT NULL DEFAULT '',
        cuenta    TEXT NOT NULL DEFAULT '',
        cci       TEXT NOT NULL DEFAULT '',
        yape      TEXT NOT NULL DEFAULT ''
      )
    ''',
    // `clave` queda siempre vacía: es la columna donde antes iba la contraseña
    // tal cual, y SQLite no deja borrar columnas en todas las versiones que
    // traen los teléfonos. Sin huella significa "la de fábrica".
    '''
      CREATE TABLE auth (
        id           INTEGER PRIMARY KEY,
        usuario      TEXT    NOT NULL,
        clave        TEXT    NOT NULL DEFAULT '',
        correo       TEXT,
        claveHuella  TEXT,
        claveSal     TEXT,
        claveVueltas INTEGER
      )
    ''',
  ];

  /// Siembra el usuario por defecto **solo** la primera vez: nunca pisa una
  /// clave que el usuario ya cambió. Va sin huella, que es como se guarda la
  /// de fábrica.
  Future<void> _sembrarAuth() async {
    final existente = await db.query('auth', where: 'id = 1', limit: 1);
    if (existente.isEmpty) {
      await db.insert('auth', {'id': 1, 'usuario': usuarioInicial, 'clave': ''});
    }
  }

  Future<void> cerrar() async {
    await db.close();
    _instancia = null;
  }
}
