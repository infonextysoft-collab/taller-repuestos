import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/calculadora_totales.dart';

/// El descuento de una línea: lo que se le rebaja a **un** repuesto o a **un**
/// trabajo, y que sale impreso en su renglón de la boleta.
void main() {
  group('el importe de la línea', () {
    test('sin descuento es cantidad por precio', () {
      const l = LineaRepuesto(desc: 'Filtro', cantidad: 3, precio: 20);

      expect(l.importe, 60);
      expect(l.rebaja, 0);
    });

    test('con descuento rebaja el importe, no el precio unitario', () {
      const l =
          LineaRepuesto(desc: 'Filtro', cantidad: 3, precio: 20, dto: 10);

      expect(l.precio, 20, reason: 'el precio de lista no se toca');
      expect(l.importe, 54);
      expect(l.rebaja, 6);
    });

    test('la mano de obra también se puede rebajar', () {
      const l = LineaMano(desc: 'Rebobinado', precio: 300, dto: 25);

      expect(l.importe, 225);
      expect(l.rebaja, 75);
    });

    test('regalar la línea la deja en cero, no en negativo', () {
      const l = LineaMano(desc: 'Revisión', precio: 80, dto: 100);

      expect(l.importe, 0);
    });

    test('un porcentaje imposible se corta en 100', () {
      const l = LineaMano(desc: 'Revisión', precio: 80, dto: 130);

      expect(l.dtoValido, 100);
      expect(l.importe, 0, reason: 'nunca se le devuelve plata al cliente');
    });

    test('redondea a céntimos, sin arrastrar decimales', () {
      const l =
          LineaRepuesto(desc: 'Junta', cantidad: 3, precio: 33.33, dto: 15);

      expect(l.importe, 84.99, reason: '99.99 menos el 15 %');
    });
  });

  group('lo que se guarda', () {
    test('una línea vieja, sin el campo, vale cero', () {
      final l = LineaRepuesto.fromJson(const {
        'desc': 'Filtro',
        'cant': 2,
        'precio': 50,
      });

      expect(l.dto, 0);
      expect(l.importe, 100);
    });

    test('sin descuento no se escribe la clave', () {
      const l = LineaMano(desc: 'Balanceo', precio: 100);

      expect(l.toJson().containsKey('dto'), isFalse);
    });

    test('con descuento va y vuelve igual', () {
      const l = LineaRepuesto(
        desc: 'Filtro',
        cantidad: 2,
        precio: 50,
        costo: 30,
        dto: 12.5,
      );

      final vuelta = LineaRepuesto.fromJson(l.toJson());

      expect(vuelta.dto, 12.5);
      expect(vuelta.importe, l.importe);
      expect(vuelta.costo, 30);
    });
  });

  group('los totales del trabajo', () {
    test('los subtotales ya vienen con la rebaja adentro', () {
      const t = Trabajo(
        tipo: TipoTrabajo.taller,
        trabajosRealizados: [
          LineaMano(desc: 'Rebobinado', precio: 300, dto: 10),
        ],
        repuestos: [
          LineaRepuesto(desc: 'Filtro', cantidad: 2, precio: 50, dto: 20),
        ],
      );

      final tot = calculadora.calcular(t);

      expect(tot.subTrabajos, 270);
      expect(tot.subRepuestos, 80);
      expect(tot.subtotal, 350);
      expect(tot.total, 350);
    });

    test('el IGV sale sobre lo que de verdad se cobró', () {
      const t = Trabajo(
        tipo: TipoTrabajo.venta,
        repuestos: [
          LineaRepuesto(desc: 'Filtro', cantidad: 1, precio: 118, dto: 50),
        ],
      );

      final tot = calculadora.calcular(t);

      expect(tot.total, 59);
      expect(tot.gravado + tot.igv, tot.total);
    });

    test('lo rebajado se puede sumar aparte, para mostrarlo', () {
      const lineas = [
        LineaRepuesto(desc: 'Filtro', cantidad: 2, precio: 50, dto: 10),
        LineaRepuesto(desc: 'Junta', cantidad: 1, precio: 20),
      ];

      expect(calculadora.sumarRebajas(lineas), 10);
      expect(calculadora.sumarLineas(lineas), 110);
    });
  });
}
