import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/totales.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/ganancia.dart';

void main() {
  Trabajo conRepuestos(List<LineaRepuesto> repuestos, {double cobrado = 500}) =>
      Trabajo(
        codigo: 'REP-2026-0001',
        tipo: TipoTrabajo.taller,
        trabajosRealizados: const [
          LineaMano(desc: 'Mano de obra', precio: 300),
        ],
        repuestos: repuestos,
        totales: Totales(total: cobrado),
      );

  test('resta lo que costaron los repuestos, no la mano de obra', () {
    final g = gananciaDe(conRepuestos(const [
      LineaRepuesto(desc: 'Filtro', cantidad: 2, precio: 50, costo: 30),
    ]));

    expect(g.cobrado, 500);
    expect(g.costo, 60);
    expect(g.neta, 440);
    expect(g.completa, isTrue);
  });

  test('sin repuestos, todo lo cobrado es ganancia', () {
    final g = gananciaDe(conRepuestos(const []));

    expect(g.costo, 0);
    expect(g.neta, 500);
    expect(g.completa, isTrue);
  });

  test('un repuesto sin costo no se cuenta como gratis: se avisa', () {
    final g = gananciaDe(conRepuestos(const [
      LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 50, costo: 30),
      LineaRepuesto(desc: 'Junta', cantidad: 1, precio: 20),
    ]));

    expect(g.costo, 30, reason: 'solo suma lo que sí se sabe');
    expect(g.sinCosto, 1);
    expect(g.completa, isFalse);
    expect(g.neta, 470, reason: 'es un techo, no la ganancia real');
  });

  test('cuenta cuántas líneas quedaron mudas, no cuántas unidades', () {
    final g = gananciaDe(conRepuestos(const [
      LineaRepuesto(desc: 'Junta', cantidad: 7, precio: 20),
      LineaRepuesto(desc: 'Perno', cantidad: 3, precio: 5),
    ]));

    expect(g.sinCosto, 2);
  });

  test('vender por debajo del costo da ganancia negativa', () {
    final g = gananciaDe(conRepuestos(
      const [LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 50, costo: 80)],
      cobrado: 50,
    ));

    expect(g.neta, -30);
  });

  test('el porcentaje sale sobre lo cobrado, y sin cobrar no hay', () {
    final g = gananciaDe(conRepuestos(
      const [LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 50, costo: 25)],
      cobrado: 100,
    ));

    expect(g.porcentaje, 75);
    expect(gananciaDe(conRepuestos(const [], cobrado: 0)).porcentaje, isNull);
  });
}
