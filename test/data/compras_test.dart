import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/compras_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/domain/entities/compra.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';

/// Las compras son la puerta por la que sube el stock: lo que se prueba acá es
/// que la puerta mueva el inventario y que deshacerla lo devuelva.
void main() {
  late AppDatabase base;
  late ComprasRepositorySqlite compras;
  late InventarioRepositorySqlite inventario;
  late int idBujia;

  setUp(() async {
    base = await AppDatabase.enMemoria();
    compras = ComprasRepositorySqlite(base);
    inventario = InventarioRepositorySqlite(base);

    idBujia = await inventario.crear(
      const Repuesto(nombre: 'BUJIA', stock: 2, precio: 30, precioCosto: 18),
    );
  });

  tearDown(() => base.cerrar());

  Compra deBujias(int cantidad, double costo, {String proveedor = ''}) => Compra(
        fecha: '2026-09-20',
        proveedor: proveedor,
        lineas: [
          LineaCompra(
            desc: 'BUJIA',
            cantidad: cantidad,
            costo: costo,
            inventarioId: idBujia,
          ),
        ],
      );

  test('registrar sube el stock y deja el nuevo precio de compra', () async {
    await compras.registrar(deBujias(10, 21));

    final item = (await inventario.obtener(idBujia))!;
    expect(item.stock, 12, reason: 'las 2 que había más las 10 que entraron');
    expect(item.precioCosto, 21, reason: 'ahora cuesta lo último que se pagó');
  });

  test('una línea sin repuesto queda como registro y no mueve nada', () async {
    await compras.registrar(const Compra(
      fecha: '2026-09-20',
      lineas: [LineaCompra(desc: 'Trapos', cantidad: 5, costo: 2)],
    ));

    expect((await inventario.obtener(idBujia))!.stock, 2);
    expect((await compras.listar()).single.total, 10);
  });

  test('eliminar devuelve las unidades que habían entrado', () async {
    final guardada = await compras.registrar(deBujias(10, 21));
    expect((await inventario.obtener(idBujia))!.stock, 12);

    await compras.eliminar(guardada.id!);

    expect((await inventario.obtener(idBujia))!.stock, 2);
    expect(await compras.listar(), isEmpty);
  });

  test('eliminar no deja el stock en negativo si ya se vendió', () async {
    final guardada = await compras.registrar(deBujias(10, 21));

    // Se vendieron 11 de las 12 que quedaron.
    await inventario.agregarRepuesto(
        inventarioId: idBujia, desc: 'BUJIA', cant: 11);
    expect((await inventario.obtener(idBujia))!.stock, 1);

    await compras.eliminar(guardada.id!);

    expect((await inventario.obtener(idBujia))!.stock, 0,
        reason: 'el stock real es el que hay, no un número negativo');
  });

  test('las de un repuesto salen de la más nueva a la más vieja', () async {
    await compras.registrar(deBujias(5, 18).copyWith(fecha: '2026-08-01'));
    await compras.registrar(deBujias(5, 20).copyWith(fecha: '2026-09-15'));
    await compras.registrar(const Compra(
      fecha: '2026-09-20',
      lineas: [LineaCompra(desc: 'Otra cosa', cantidad: 1, costo: 5)],
    ));

    final delRepuesto = await compras.deRepuesto(idBujia);

    expect(delRepuesto.length, 2, reason: 'la de "Otra cosa" no es suya');
    expect(delRepuesto.first.fecha, '2026-09-15');
  });

  group('proveedores frecuentes', () {
    test('van los más repetidos primero', () async {
      await compras.registrar(deBujias(1, 18, proveedor: 'Repuestos Lima'));
      await compras.registrar(deBujias(1, 18, proveedor: 'Repuestos Lima'));
      await compras.registrar(deBujias(1, 18, proveedor: 'Don Pepe'));

      expect(await compras.proveedoresFrecuentes(), ['Repuestos Lima', 'Don Pepe']);
    });

    test('mayúsculas y tildes no hacen dos proveedores distintos', () async {
      await compras.registrar(deBujias(1, 18, proveedor: 'Repuestos Lima'));
      await compras.registrar(deBujias(1, 18, proveedor: 'repuestos lima'));
      await compras.registrar(deBujias(1, 18, proveedor: 'Fábrica Sur'));
      await compras.registrar(deBujias(1, 18, proveedor: 'Fabrica Sur'));
      await compras.registrar(deBujias(1, 18, proveedor: 'Fabrica Sur'));

      final lista = await compras.proveedoresFrecuentes();

      expect(lista.length, 2);
      expect(lista.first, 'Fabrica Sur', reason: 'tres contra dos');
    });

    test('las compras sin proveedor no ocupan lugar en la lista', () async {
      await compras.registrar(deBujias(1, 18));
      await compras.registrar(deBujias(1, 18, proveedor: '   '));
      await compras.registrar(deBujias(1, 18, proveedor: 'Don Pepe'));

      expect(await compras.proveedoresFrecuentes(), ['Don Pepe']);
    });
  });
}
