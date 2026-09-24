import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/totales.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/estadisticas.dart';

void main() {
  Trabajo con(List<LineaRepuesto> repuestos) => Trabajo(
        codigo: 'REP-2026-0001',
        tipo: TipoTrabajo.taller,
        repuestos: repuestos,
        totales: const Totales(total: 500),
      );

  test('junta las unidades del mismo repuesto entre trabajos distintos', () {
    final lista = ventasPorRepuesto([
      con(const [
        LineaRepuesto(desc: 'Filtro', cantidad: 2, precio: 40, costo: 25),
      ]),
      con(const [
        LineaRepuesto(desc: 'Filtro', cantidad: 3, precio: 40, costo: 25),
      ]),
    ]);

    expect(lista.single.unidades, 5);
    expect(lista.single.cobrado, 200);
    expect(lista.single.ganancia, 75);
  });

  test('lo comprado afuera suma con lo que salió del inventario', () {
    // Es el caso de la línea que se divide sola: mismo repuesto, dos orígenes.
    final lista = ventasPorRepuesto([
      con(const [
        LineaRepuesto(
          desc: 'Bujía',
          cantidad: 2,
          precio: 30,
          costo: 18,
          origen: OrigenRepuesto.inventario,
          inventarioId: 7,
        ),
        LineaRepuesto(desc: 'Bujía', cantidad: 3, precio: 30, costo: 18),
      ]),
    ]);

    expect(lista.single.unidades, 5);
    expect(lista.single.inventarioId, 7, reason: 'se queda con el id que hay');
  });

  test('el mismo nombre escrito distinto es el mismo repuesto', () {
    final lista = ventasPorRepuesto([
      con(const [LineaRepuesto(desc: 'Bujía', cantidad: 1, precio: 30)]),
      con(const [LineaRepuesto(desc: 'BUJIA', cantidad: 1, precio: 30)]),
    ]);

    expect(lista.length, 1);
    expect(lista.single.unidades, 2);
  });

  test('ordena por unidades y, en empate, por lo que dejó', () {
    final lista = ventasPorRepuesto([
      con(const [
        LineaRepuesto(desc: 'Poco', cantidad: 1, precio: 10, costo: 1),
        LineaRepuesto(desc: 'Mucho', cantidad: 9, precio: 10, costo: 1),
        LineaRepuesto(desc: 'Igual pero deja más', cantidad: 1, precio: 90, costo: 1),
      ]),
    ]);

    expect(lista.map((v) => v.nombre).toList(),
        ['Mucho', 'Igual pero deja más', 'Poco']);
  });

  test('una línea sin costo no se cuenta como gratis', () {
    final lista = ventasPorRepuesto([
      con(const [
        LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 40, costo: 25),
        LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 40),
      ]),
    ]);

    expect(lista.single.sinCosto, 1);
    expect(lista.single.completa, isFalse);
    expect(lista.single.costo, 25);
  });

  test('buscar uno puntual ignora tildes y mayúsculas', () {
    final trabajos = [
      con(const [LineaRepuesto(desc: 'Bujía NGK', cantidad: 4, precio: 30)]),
    ];

    expect(ventasDe(trabajos, 'BUJIA NGK')!.unidades, 4);
    expect(ventasDe(trabajos, 'Faja'), isNull);
  });
}
