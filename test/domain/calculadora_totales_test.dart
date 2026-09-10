import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/calculadora_totales.dart';

/// Los casos de esta prueba salieron de la app en producción. Si alguno se
/// rompe, hay plata mal cobrada o dos papeles que no cuadran entre sí.
void main() {
  group('traslado', () {
    const enCampoConMovilidadPropia = Trabajo(
      tipo: TipoTrabajo.campo,
      movilidad: Movilidad.propia,
      vueltas: 3,
      precioVuelta: 25,
    );

    test('se cobra en campo con movilidad propia', () {
      expect(calculadora.calcularTraslado(enCampoConMovilidadPropia), 75);
    });

    test('no se cobra si la movilidad la puso el cliente', () {
      final t = enCampoConMovilidadPropia.copyWith(movilidad: Movilidad.cliente);
      expect(calculadora.calcularTraslado(t), 0);
    });

    test('no se cobra en taller, aunque hayan quedado vueltas cargadas', () {
      // El bug real: elegir Campo, cargar las vueltas, volver a Taller. Mirar
      // solo la movilidad cobraría un traslado que nunca existió.
      final t = enCampoConMovilidadPropia.copyWith(tipo: TipoTrabajo.taller);
      expect(calculadora.calcularTraslado(t), 0);
    });

    test('no se cobra en una venta simple', () {
      final t = enCampoConMovilidadPropia.copyWith(tipo: TipoTrabajo.venta);
      expect(calculadora.calcularTraslado(t), 0);
    });
  });

  group('totales', () {
    // Subtotal 757.00: 500 de mano de obra + 257 de repuestos.
    final base = Trabajo(
      tipo: TipoTrabajo.taller,
      trabajosRealizados: const [
        LineaMano(desc: 'Rebobinado parcial', precio: 400),
        LineaMano(desc: 'Balanceo', precio: 100),
      ],
      repuestos: const [
        LineaRepuesto(desc: 'Rodamiento', cantidad: 2, precio: 78.5),
        LineaRepuesto(desc: 'Barniz', cantidad: 1, precio: 100),
      ],
      descuento: 60,
    );

    test('el IGV va incluido: el cliente paga subtotal menos descuento', () {
      final t = calculadora.calcular(base);

      expect(t.subTrabajos, 500);
      expect(t.subRepuestos, 257);
      expect(t.subtotal, 757);
      expect(t.descuento, 60);
      expect(t.total, 697);
    });

    test('el desagregado suma exactamente el total', () {
      final t = calculadora.calcular(base);

      expect(t.gravado, 590.68);
      expect(t.igv, 106.32);
      expect(t.gravado + t.igv, closeTo(t.total, 0.001));
    });

    test('la mano de obra no multiplica por cantidad', () {
      // Una línea de mano de obra vale su precio, punto: no hay unidades.
      final t = calculadora.calcular(const Trabajo(
        trabajosRealizados: [LineaMano(desc: 'Diagnóstico', precio: 120)],
      ));
      expect(t.subTrabajos, 120);
      expect(t.total, 120);
    });

    test('el descuento nunca deja el total en negativo', () {
      final t = calculadora.calcular(base.copyWith(descuento: 9999));
      expect(t.descuento, 757);
      expect(t.total, 0);
    });

    test('un descuento negativo se ignora', () {
      final t = calculadora.calcular(base.copyWith(descuento: -50));
      expect(t.descuento, 0);
      expect(t.total, 757);
    });

    test('el traslado entra en el subtotal', () {
      final t = calculadora.calcular(base.copyWith(
        tipo: TipoTrabajo.campo,
        movilidad: Movilidad.propia,
        vueltas: 2,
        precioVuelta: 20,
      ));

      expect(t.subTraslado, 40);
      expect(t.subtotal, 797);
      expect(t.total, 737);
    });
  });

  group('boletas separadas', () {
    final base = Trabajo(
      tipo: TipoTrabajo.taller,
      trabajosRealizados: const [
        LineaMano(desc: 'Rebobinado parcial', precio: 400),
        LineaMano(desc: 'Balanceo', precio: 100),
      ],
      repuestos: const [
        LineaRepuesto(desc: 'Rodamiento', cantidad: 2, precio: 78.5),
        LineaRepuesto(desc: 'Barniz', cantidad: 1, precio: 100),
      ],
      descuento: 60,
      vistaDoc: VistaDoc.separado,
    );

    test('el modo junto emite una sola boleta', () {
      final boletas =
          calculadora.calcularBoletas(base.copyWith(vistaDoc: VistaDoc.junto));

      expect(boletas.length, 1);
      expect(boletas.single.total, 697);
    });

    test('las dos boletas suman el mismo total y el mismo IGV que la junta', () {
      // El invariante. Si el descuento y el IGV de la segunda se recalculan
      // por separado en vez de salir por diferencia, el redondeo deja un
      // céntimo colgado y los papeles no cuadran.
      final junta = calculadora.calcular(base);
      final boletas = calculadora.calcularBoletas(base);

      expect(boletas.length, 2);

      final sumaTotal = boletas.fold<double>(0, (a, b) => a + b.total);
      final sumaIgv = boletas.fold<double>(0, (a, b) => a + b.igv);

      expect(sumaTotal, closeTo(junta.total, 0.001));
      expect(sumaIgv, closeTo(junta.igv, 0.001));
    });

    test('el traslado viaja con la mano de obra', () {
      final conTraslado = base.copyWith(
        tipo: TipoTrabajo.campo,
        movilidad: Movilidad.propia,
        vueltas: 2,
        precioVuelta: 20,
      );

      final junta = calculadora.calcular(conTraslado);
      final boletas = calculadora.calcularBoletas(conTraslado);

      // 500 de mano de obra + 40 de traslado, antes del descuento.
      expect(boletas.first.subtotal, 540);
      expect(boletas.first.incluyeRepuestos, isFalse);
      expect(boletas.last.incluyeManoDeObra, isFalse);

      expect(
        boletas.fold<double>(0, (a, b) => a + b.total),
        closeTo(junta.total, 0.001),
      );
    });

    test('cada boleta cierra su propio gravado + IGV', () {
      for (final b in calculadora.calcularBoletas(base)) {
        expect(b.gravado + b.igv, closeTo(b.total, 0.001));
      }
    });
  });
}
