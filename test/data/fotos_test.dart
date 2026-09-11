import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/imagenes.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart';
import 'package:taller_repuestos/domain/entities/foto.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';

/// Las fotos viven en su propia tabla, con los bytes crudos.
///
/// Lo que se verifica acá es lo que no se ve en pantalla: que no se dupliquen
/// al volver a guardar, que no se reescriban sin motivo, que el listado no las
/// arrastre, y que las de la versión vieja —guardadas como texto adentro del
/// registro— se muden sin perderse.
void main() {
  late AppDatabase base;
  late TrabajosRepositorySqlite trabajos;

  Uint8List bytes(int semilla) =>
      Uint8List.fromList(List.generate(64, (i) => (i + semilla) % 256));

  setUp(() async {
    base = await AppDatabase.enMemoria();
    trabajos = TrabajosRepositorySqlite(base, InventarioRepositorySqlite(base));
  });

  tearDown(() => base.cerrar());

  Future<Trabajo> conFotos(List<Foto> fotos) async {
    final creado = await trabajos.crear(const Trabajo(fecha: '2026-09-10'));
    return trabajos.actualizar(creado.copyWith(fotosIngreso: fotos));
  }

  test('guardar deja las fotos con id y se leen de vuelta', () async {
    final guardado = await conFotos([
      Foto(bytes: bytes(1), mini: bytes(9)),
      Foto(bytes: bytes(2)),
    ]);

    expect(guardado.fotosIngreso.map((f) => f.id), everyElement(isNotNull));

    final releido = await trabajos.obtener(guardado.id!);
    expect(releido!.fotosIngreso, hasLength(2));
    expect(releido.fotosIngreso.first.bytes, bytes(1));
    expect(releido.fotosIngreso.first.mini, bytes(9));
    // Nace sin subir: es lo que despues va a marcar que falta respaldarla.
    expect(releido.fotosIngreso.first.subida, isFalse);
  });

  test('volver a guardar no duplica ni cambia los ids', () async {
    final guardado = await conFotos([Foto(bytes: bytes(1))]);
    final idOriginal = guardado.fotosIngreso.single.id;

    final otraVez = await trabajos.actualizar(
      guardado.copyWith(cliente: 'Cambió el nombre'),
    );

    expect(otraVez.fotosIngreso, hasLength(1));
    expect(otraVez.fotosIngreso.single.id, idOriginal);
  });

  test('quitar una foto la borra de la base', () async {
    final guardado = await conFotos([
      Foto(bytes: bytes(1)),
      Foto(bytes: bytes(2)),
    ]);

    final sinLaSegunda = await trabajos.actualizar(
      guardado.copyWith(fotosIngreso: [guardado.fotosIngreso.first]),
    );

    expect(sinLaSegunda.fotosIngreso, hasLength(1));

    final releido = await trabajos.obtener(guardado.id!);
    expect(releido!.fotosIngreso, hasLength(1));
  });

  test('el listado no carga las fotos, solo la miniatura', () async {
    await conFotos([Foto(bytes: bytes(1), mini: bytes(9))]);

    final lista = await trabajos.listar();
    expect(lista.single.fotosIngreso, isEmpty);
    expect(lista.single.miniatura, bytes(9));
  });

  test('sin versión chica, el listado cae a la foto completa', () async {
    await conFotos([Foto(bytes: bytes(3))]);

    final lista = await trabajos.listar();
    expect(lista.single.miniatura, bytes(3));
  });

  test('borrar el trabajo se lleva sus fotos', () async {
    final guardado = await conFotos([Foto(bytes: bytes(1))]);
    await trabajos.eliminar(guardado.id!);

    final quedan = await base.db.query('fotos');
    expect(quedan, isEmpty);
  });

  group('migración de la versión vieja', () {
    test('las fotos en base64 se mudan a la tabla y dejan la columna vacía',
        () async {
      final creado = await trabajos.crear(const Trabajo(fecha: '2026-09-10'));

      // Así quedaban antes: una lista JSON de data URIs adentro del registro.
      await base.db.update(
        'trabajos',
        {
          'fotosIngreso':
              '["${fotoDesdeBytes(bytes(5))}","${fotoDesdeBytes(bytes(6))}"]',
          'fotosEntrega': '["${fotoDesdeBytes(bytes(7))}"]',
        },
        where: 'id = ?',
        whereArgs: [creado.id],
      );

      await AppDatabase.mudarFotos(base.db);

      final releido = await trabajos.obtener(creado.id!);
      expect(releido!.fotosIngreso.map((f) => f.bytes), [bytes(5), bytes(6)]);
      expect(releido.fotosEntrega.single.bytes, bytes(7));

      final fila = (await base.db
              .query('trabajos', where: 'id = ?', whereArgs: [creado.id]))
          .single;
      expect(fila['fotosIngreso'], '[]');
      expect(fila['fotosEntrega'], '[]');
    });

    test('una foto ilegible se descarta sin tumbar la migración', () async {
      final creado = await trabajos.crear(const Trabajo(fecha: '2026-09-10'));

      await base.db.update(
        'trabajos',
        {'fotosIngreso': '["no soy una imagen","${fotoDesdeBytes(bytes(4))}"]'},
        where: 'id = ?',
        whereArgs: [creado.id],
      );

      await AppDatabase.mudarFotos(base.db);

      // Es preferible perder una imagen rota a que la app no abra nunca más.
      final releido = await trabajos.obtener(creado.id!);
      expect(releido!.fotosIngreso.single.bytes, bytes(4));
    });
  });
}
