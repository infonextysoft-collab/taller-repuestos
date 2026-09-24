import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taller_repuestos/core/utils/clave_segura.dart';
import 'package:taller_repuestos/core/utils/imagenes.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/compras_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/negocio_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/recordatorios_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart';
import 'package:taller_repuestos/domain/entities/compra.dart';
import 'package:taller_repuestos/domain/entities/repeticion.dart';

/// Abrir una base que ya existe.
///
/// Hasta la versión 4 el teléfono abría la base siempre como "versión 1" y sin
/// migraciones. Nunca falló a la vista porque una instalación nueva se crea con
/// el esquema completo, pero dejó en la calle bases que **dicen** 1 y traen
/// otra cosa adentro. Estos tests abren copias fieles de esas bases, por el
/// mismo camino que usa la app, y verifican que nada revienta ni se pierde.
void main() {
  late Directory carpeta;

  setUpAll(sqfliteFfiInit);

  setUp(() => carpeta = Directory.systemTemp.createTempSync('ms_migracion_'));

  tearDown(() {
    try {
      carpeta.deleteSync(recursive: true);
    } catch (_) {
      // En Windows el archivo puede tardar en soltarse; es una carpeta
      // temporal y el sistema la limpia igual.
    }
  });

  Uint8List bytes(int semilla) =>
      Uint8List.fromList(List.generate(64, (i) => (i + semilla) % 256));

  /// Deja en disco una base sellada como versión 1, con el esquema y los datos
  /// que se le pasen.
  Future<String> baseVieja(
    List<String> esquema,
    Future<void> Function(Database d) datos,
  ) async {
    final ruta = p.join(carpeta.path, 'parte.db');
    final d = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          for (final sentencia in esquema) {
            await d.execute(sentencia);
          }
          await datos(d);
        },
      ),
    );
    await d.close();
    return ruta;
  }

  Future<Map<String, Object?>> filaAuth(AppDatabase base) async =>
      (await base.db.query('auth', where: 'id = 1')).single;

  group('la base de la vista web (esquema v2, sellada como v1)', () {
    late String ruta;

    setUp(() async {
      ruta = await baseVieja(_esquemaWeb, (d) async {
        await d.insert('trabajos', {
          'codigo': 'REP-2026-0001',
          'tipo': 'taller',
          'estado': 'pendiente',
          'fecha': '2026-09-09',
          'cliente': 'Juan Ramírez',
          // Así se guardaban: una lista JSON de data URIs dentro del registro.
          'fotosIngreso': '["${fotoDesdeBytes(bytes(1))}"]',
        });
        await d.insert('recordatorios', {
          'descripcion': 'Engrase de la bomba',
          'fecha': '2026-12-01',
          'repetirCada': 15,
          'repetirUnidad': 'dias',
        });
        await d.insert('auth', {
          'id': 1,
          'usuario': 'Samuel',
          'clave': 'MiClave99',
        });
      });
    });

    test('abre sin reventar y queda en la versión actual', () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      expect(await base.db.getVersion(), AppDatabase.version);
    });

    test('crea la tabla de fotos y muda las que estaban en el registro',
        () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      final trabajos =
          TrabajosRepositorySqlite(base, InventarioRepositorySqlite(base));
      final id = (await trabajos.listar()).single.id!;
      final completo = await trabajos.obtener(id);

      expect(completo!.fotosIngreso.single.bytes, bytes(1));
    });

    test('un recordatorio "cada 15 días" sigue siendo cada 15 días', () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      final lista = await RecordatoriosRepositorySqlite(base).listar();
      expect(lista.single.repite, const Repeticion(15, UnidadRepeticion.dias));
    });

    test('la contraseña deja de estar en texto plano y sigue sirviendo',
        () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      final fila = await filaAuth(base);
      expect(fila['clave'], '');
      expect(fila['claveHuella'], isNotNull);

      final huella = HuellaClave(
        huella: fila['claveHuella'] as String,
        sal: fila['claveSal'] as String,
        vueltas: (fila['claveVueltas'] as num).toInt(),
      );
      expect(huella.coincide('MiClave99'), isTrue);
      expect(huella.coincide('Admin123'), isFalse);
    });
  });

  group('la base del primer APK (esquema v3, sellada como v1)', () {
    late String ruta;

    setUp(() async {
      ruta = await baseVieja([..._esquemaWeb, ..._fotosV3], (d) async {
        final id = await d.insert('trabajos', {
          'codigo': 'REP-2026-0001',
          'tipo': 'taller',
          'estado': 'terminado',
          'fecha': '2026-09-10',
          'cliente': 'Carmen Díaz',
        });
        await d.insert('fotos', {
          'trabajoId': id,
          'momento': 'ingreso',
          'orden': 0,
          'bytes': bytes(7),
        });
        await d.insert('recordatorios', {
          'descripcion': 'Revisión general',
          'fecha': '2027-01-10',
          'repetirCada': 2,
          'repetirUnidad': 'anios',
          'importante': 1,
        });
        await d.insert('auth', {
          'id': 1,
          'usuario': 'Samuel',
          'clave': claveInicial,
        });
      });
    });

    test('abre sin intentar agregar lo que ya tiene', () async {
      // Es el caso que habría roto la app instalada: la versión dice 1, el
      // esquema es el de la 3, y la migración 1 → 2 intenta agregar columnas
      // que ya existen.
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      expect(await base.db.getVersion(), AppDatabase.version);
    });

    test('no duplica las fotos ni toca los recordatorios', () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      expect(await base.db.query('fotos'), hasLength(1));

      final recordatorio =
          (await RecordatoriosRepositorySqlite(base).listar()).single;
      expect(recordatorio.repite, const Repeticion(2, UnidadRepeticion.anios));
      expect(recordatorio.importante, isTrue);
    });

    test('la clave de fábrica queda sin huella y sin texto', () async {
      final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
      addTearDown(base.cerrar);

      final fila = await filaAuth(base);
      expect(fila['clave'], '');
      expect(fila['claveHuella'], isNull);
    });
  });

  test('abrir dos veces la misma base no vuelve a migrar', () async {
    final ruta = await baseVieja(_esquemaWeb, (d) async {
      await d.insert('auth', {'id': 1, 'usuario': 'Samuel', 'clave': 'Otra123'});
    });

    final primera = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
    final huella = (await filaAuth(primera))['claveHuella'];
    await primera.cerrar();

    final segunda = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
    addTearDown(segunda.cerrar);

    // Si migrara otra vez, la sal cambiaría y con ella la huella.
    expect((await filaAuth(segunda))['claveHuella'], huella);
  });

  test('una instalación nueva nace en la versión actual con la de fábrica',
      () async {
    final base = await AppDatabase.abrirEn(
      databaseFactoryFfi,
      p.join(carpeta.path, 'nueva.db'),
    );
    addTearDown(base.cerrar);

    expect(await base.db.getVersion(), AppDatabase.version);

    final fila = await filaAuth(base);
    expect(fila['usuario'], usuarioInicial);
    expect(fila['clave'], '');
    expect(fila['claveHuella'], isNull);
  });

  test('el negocio gana con qué cobrar sin perder lo que ya tenía', () async {
    final ruta = await baseVieja(_esquemaWeb, (d) async {
      await d.insert('negocio', {
        'id': 1,
        'nombre': 'Servicios MS',
        'ruc': '20131312955',
        'telefono': '999888777',
      });
      await d.insert('auth', {'id': 1, 'usuario': 'Samuel', 'clave': 'Clave99'});
    });

    final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
    addTearDown(base.cerrar);
    final negocio = NegocioRepositorySqlite(base);

    final antes = await negocio.obtener();
    expect(antes.nombre, 'Servicios MS');
    expect(antes.telefono, '999888777');
    expect(antes.datosPago, isEmpty, reason: 'nace sin datos de cobro');

    await negocio.guardar(
      antes.copyWith(banco: 'BCP', cuenta: '191-0123456-0-12'),
    );

    final despues = await negocio.obtener();
    expect(despues.datosPago.single.valor, '191-0123456-0-12');
    expect(despues.nombre, 'Servicios MS');
  });

  test('el inventario gana el precio de compra sin tocar lo que vale',
      () async {
    final ruta = await baseVieja(_esquemaWeb, (d) async {
      await d.insert('inventario', {
        'nombre': 'MOTOR',
        'stock': 3,
        'precio': 100.0,
      });
      await d.insert('auth', {'id': 1, 'usuario': 'Samuel', 'clave': 'Clave99'});
    });

    final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
    addTearDown(base.cerrar);

    final item = (await InventarioRepositorySqlite(base).listar()).single;
    expect(item.nombre, 'MOTOR');
    expect(item.stock, 3);
    expect(item.precio, 100);
    expect(item.precioCosto, 0);
    expect(item.utilidad, isNull,
        reason: 'lo cargado antes de este campo no sabe cuánto costó');
  });

  test('una base vieja estrena la tabla de compras, vacía y usable', () async {
    final ruta = await baseVieja(_esquemaWeb, (d) async {
      await d.insert('inventario', {'nombre': 'BUJIA', 'stock': 2, 'precio': 30.0});
      await d.insert('auth', {'id': 1, 'usuario': 'Samuel', 'clave': 'Clave99'});
    });

    final base = await AppDatabase.abrirEn(databaseFactoryFfi, ruta);
    addTearDown(base.cerrar);

    final compras = ComprasRepositorySqlite(base);
    expect(await compras.listar(), isEmpty);

    final inventario = InventarioRepositorySqlite(base);
    final id = (await inventario.listar()).single.id!;
    await compras.registrar(Compra(
      fecha: '2026-09-20',
      proveedor: 'Don Pepe',
      lineas: [
        LineaCompra(desc: 'BUJIA', cantidad: 5, costo: 18, inventarioId: id),
      ],
    ));

    expect((await inventario.obtener(id))!.stock, 7);
    expect((await compras.listar()).single.proveedor, 'Don Pepe');
  });
}

/// El esquema tal como lo creaba la app publicada en la vista web (commit
/// 738c046): ya con las columnas de la v2, sin tabla de fotos y con la
/// contraseña en texto plano. Copiado a mano a propósito — si alguien cambia el
/// esquema actual, esta foto del pasado no se tiene que mover con él.
const List<String> _esquemaWeb = [
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

/// Lo que el primer APK (commit 03bc80c) sumaba encima: la tabla de fotos.
const List<String> _fotosV3 = [
  '''
    CREATE TABLE fotos (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      trabajoId INTEGER NOT NULL,
      momento   TEXT    NOT NULL,
      orden     INTEGER NOT NULL DEFAULT 0,
      bytes     BLOB    NOT NULL,
      mini      BLOB,
      remota    TEXT
    )
  ''',
  'CREATE INDEX ix_fotos_trabajo ON fotos(trabajoId, momento, orden)',
];
