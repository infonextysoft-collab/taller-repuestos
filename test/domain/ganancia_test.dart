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

  /// Uno con los totales congelados completos, que es como quedan los
  /// trabajos cerrados de verdad: es lo que permite separar las dos mitades.
  Trabajo cerrado({
    double mano = 300,
    double traslado = 0,
    double piezas = 200,
    double descuento = 0,
    List<LineaRepuesto> repuestos = const [],
  }) {
    final subtotal = mano + traslado + piezas;
    return Trabajo(
      codigo: 'REP-2026-0002',
      tipo: TipoTrabajo.taller,
      repuestos: repuestos,
      totales: Totales(
        subTrabajos: mano,
        subTraslado: traslado,
        subRepuestos: piezas,
        subtotal: subtotal,
        descuento: descuento,
        total: subtotal - descuento,
      ),
    );
  }

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

  group('partida en dos', () {
    test('la mano de obra es ganancia entera; las piezas, lo que dejan', () {
      final g = gananciaDe(cerrado(
        mano: 300,
        piezas: 200,
        repuestos: const [
          LineaRepuesto(desc: 'Filtro', cantidad: 2, precio: 100, costo: 60),
        ],
      ));

      expect(g.netaMano, 300, reason: 'tu tiempo no tiene costo de mercadería');
      expect(g.netaRepuestos, 80, reason: '200 cobrados menos 120 de costo');
      expect(g.neta, 380);
    });

    test('el traslado cuenta como mano de obra', () {
      final g = gananciaDe(cerrado(mano: 300, traslado: 75, piezas: 0));

      expect(g.netaMano, 375);
      expect(g.netaRepuestos, 0);
    });

    test('las dos mitades suman exactamente lo cobrado', () {
      // Un descuento que no se reparte redondo: 100 sobre 757.
      final g = gananciaDe(cerrado(mano: 500, piezas: 257, descuento: 100));

      expect(g.cobradoMano + g.cobradoRepuestos, g.cobrado);
      expect(g.cobrado, 657);
    });

    test('el descuento se reparte en proporción, no todo a un lado', () {
      final g = gananciaDe(cerrado(mano: 300, piezas: 100, descuento: 40));

      expect(g.cobradoMano, 270, reason: 'le toca el 75 % del descuento');
      expect(g.cobradoRepuestos, 90);
    });

    test('vender por debajo del costo deja la mitad de piezas en rojo', () {
      final g = gananciaDe(cerrado(
        mano: 0,
        piezas: 50,
        repuestos: const [
          LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 50, costo: 80),
        ],
      ));

      expect(g.netaRepuestos, -30);
      expect(g.netaMano, 0);
    });
  });
}
