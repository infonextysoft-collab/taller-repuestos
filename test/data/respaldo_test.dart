import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/negocio_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/recordatorios_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart';
import 'package:taller_repuestos/data/respaldo/respaldo_zip.dart';
import 'package:taller_repuestos/domain/entities/foto.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/repositories/respaldo_repository.dart';

/// El respaldo es lo único que hay entre un teléfono perdido y empezar de cero,
/// así que lo que se prueba acá es que **vuelva todo**, fotos incluidas.
void main() {
  Uint8List bytes(int semilla) =>
      Uint8List.fromList(List.generate(48, (i) => (i + semilla) % 256));

  late AppDatabase base;
  late RespaldoZip respaldo;
  late TrabajosRepositorySqlite trabajos;
  late InventarioRepositorySqlite inventario;
  late RecordatoriosRepositorySqlite recordatorios;
  late NegocioRepositorySqlite negocio;

  setUp(() async {
    base = await AppDatabase.enMemoria();
    inventario = InventarioRepositorySqlite(base);
    trabajos = TrabajosRepositorySqlite(base, inventario);
    recordatorios = RecordatoriosRepositorySqlite(base);
    negocio = NegocioRepositorySqlite(base);
    respaldo = RespaldoZip(base);
  });

  tearDown(() => base.cerrar());

  Future<void> sembrar() async {
    await negocio.guardar(const Negocio(
      nombre: 'Servicios MS',
      ruc: '20131312955',
      direccion: 'Av. Industrial 455',
    ));
    await inventario.crear(
        const Repuesto(nombre: 'Filtro de aceite', stock: 12, precio: 38.5));

    final creado = await trabajos.crear(
        const Trabajo(fecha: '2026-09-10', tipo: TipoTrabajo.taller));
    await trabajos.actualizar(creado.copyWith(
      cliente: 'Juan Ramírez',
      equipo: 'Compresor Atlas',
      trabajosRealizados: const [LineaMano(desc: 'Mantenimiento', precio: 180)],
      fotosIngreso: [Foto(bytes: bytes(1), mini: bytes(9))],
      fotosEntrega: [Foto(bytes: bytes(2))],
    ));

    await recordatorios.crear(const Recordatorio(
      descripcion: 'Revisar en 3 meses',
      fecha: '2026-12-10',
      importante: true,
    ));
  }

  test('exportar y restaurar en una base vacía devuelve todo', () async {
    await sembrar();
    final archivo = await respaldo.exportar();

    // El teléfono nuevo: otra base, sin nada.
    final otra = await AppDatabase.enMemoria();
    addTearDown(otra.cerrar);
    await otra.db.delete('negocio');

    final resultado = await RespaldoZip(otra).restaurar(archivo);
    expect(resultado.trabajos, 1);
    expect(resultado.repuestos, 1);
    expect(resultado.recordatorios, 1);
    expect(resultado.fotos, 2);

    final repos = TrabajosRepositorySqlite(otra, InventarioRepositorySqlite(otra));
    final recuperado = (await repos.listar()).single;
    expect(recuperado.cliente, 'Juan Ramírez');
    expect(recuperado.codigo, 'REP-2026-0001');
    expect(recuperado.totales.total, greaterThan(0));

    final completo = await repos.obtener(recuperado.id!);
    expect(completo!.fotosIngreso.single.bytes, bytes(1));
    expect(completo.fotosIngreso.single.mini, bytes(9));
    expect(completo.fotosEntrega.single.bytes, bytes(2));

    expect((await NegocioRepositorySqlite(otra).obtener()).nombre,
        'Servicios MS');
    expect((await RecordatoriosRepositorySqlite(otra).listar()).single.importante,
        isTrue);
  });

  test('restaurar reemplaza, no mezcla', () async {
    await sembrar();
    final archivo = await respaldo.exportar();

    // Otro registro cargado después del respaldo: al restaurar tiene que irse,
    // o quedarían dos trabajos peleando por el mismo correlativo.
    final extra = await trabajos.crear(const Trabajo(fecha: '2026-09-11'));
    await trabajos.actualizar(extra.copyWith(cliente: 'Nadie'));
    expect((await trabajos.listar()), hasLength(2));

    await respaldo.restaurar(archivo);

    final quedan = await trabajos.listar();
    expect(quedan, hasLength(1));
    expect(quedan.single.cliente, 'Juan Ramírez');
  });

  test('un archivo que no es respaldo avisa en vez de romper', () async {
    expect(
      () => respaldo.restaurar(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<RespaldoInvalido>()),
    );
  });

  test('un respaldo de una versión más nueva se rechaza', () async {
    // Mejor negarse que insertar filas con columnas que esta versión no
    // conoce y dejar la base a medio escribir.
    final zip = Archive()
      ..addFile(ArchiveFile.bytes(
        'datos.json',
        utf8.encode(jsonEncode({'formato': 99, 'fecha': '2030-01-01'})),
      ));

    expect(
      () => respaldo.restaurar(Uint8List.fromList(ZipEncoder().encode(zip))),
      throwsA(isA<RespaldoInvalido>()),
    );
  });

  test('el resumen cuenta lo que hay hoy', () async {
    expect((await respaldo.resumenActual()).vacio, isTrue);

    await sembrar();
    final resumen = await respaldo.resumenActual();
    expect(resumen.trabajos, 1);
    expect(resumen.fotos, 2);
    expect(resumen.vacio, isFalse);
  });
}
