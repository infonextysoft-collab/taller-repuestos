import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';

void main() {
  group('lo que deja un repuesto', () {
    test('sin precio de compra no se inventa una ganancia', () {
      const r = Repuesto(nombre: 'Filtro', precio: 38.5);

      expect(r.utilidad, isNull);
      expect(r.margen, isNull);
    });

    test('comprado a 10 y vendido a 15 deja 5', () {
      const r = Repuesto(nombre: 'Filtro', precio: 15, precioCosto: 10);

      expect(r.utilidad, 5);
      expect(r.margen, closeTo(33.3, 0.1));
    });

    test('vendido por debajo del costo, la ganancia es negativa', () {
      const r = Repuesto(nombre: 'Filtro', precio: 8, precioCosto: 10);

      expect(r.utilidad, -2);
    });

    test('el redondeo no arrastra centavos de más', () {
      const r = Repuesto(nombre: 'Filtro', precio: 38.5, precioCosto: 22.35);

      expect(r.utilidad, 16.15);
    });

    test('sin precio de venta no hay porcentaje que calcular', () {
      const r = Repuesto(nombre: 'Filtro', precioCosto: 10);

      expect(r.margen, isNull);
    });
  });
}
