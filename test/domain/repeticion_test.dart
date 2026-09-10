import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/repeticion.dart';

void main() {
  group('siguiente fecha', () {
    test('días y semanas cuentan corrido', () {
      expect(
        const Repeticion(15, UnidadRepeticion.dias).siguiente('2026-01-20'),
        '2026-02-04',
      );
      expect(
        const Repeticion(2, UnidadRepeticion.semanas).siguiente('2026-01-20'),
        '2026-02-03',
      );
    });

    test('meses cuentan por calendario, no de a 30 días', () {
      // Es la razón de guardar la unidad y no traducir todo a días: "cada mes"
      // desde el 15 cae siempre el 15, no se va corriendo.
      expect(
        const Repeticion.meses(1).siguiente('2026-01-15'),
        '2026-02-15',
      );
    });

    test('si el día no existe en el mes destino, cae al último', () {
      expect(
        const Repeticion.meses(1).siguiente('2026-01-31'),
        '2026-02-28',
      );
    });

    test('los años son doce meses', () {
      expect(
        const Repeticion(2, UnidadRepeticion.anios).siguiente('2026-03-10'),
        '2028-03-10',
      );
    });
  });

  group('etiquetas', () {
    test('el singular no dice "1"', () {
      expect(const Repeticion.meses(1).etiqueta, 'Cada mes');
      expect(const Repeticion.meses(3).etiqueta, 'Cada 3 meses');
      expect(
        const Repeticion(15, UnidadRepeticion.dias).etiqueta,
        'Cada 15 días',
      );
    });
  });

  group('lectura de la base', () {
    test('sin intervalo devuelve null', () {
      expect(Repeticion.deFilas(null, null, null), isNull);
      expect(Repeticion.deFilas(0, 'meses', null), isNull);
    });

    test('lee las columnas nuevas', () {
      expect(
        Repeticion.deFilas(15, 'dias', null),
        const Repeticion(15, UnidadRepeticion.dias),
      );
    });

    test('un registro viejo, guardado en meses, se sigue leyendo', () {
      // Los recordatorios creados antes de que existiera la unidad solo tienen
      // `repetirMeses`. Interpretarlos como meses es exactamente lo que eran.
      expect(
        Repeticion.deFilas(null, null, 6),
        const Repeticion.meses(6),
      );
    });

    test('una unidad desconocida no rompe: cae a meses', () {
      expect(
        Repeticion.deFilas(4, 'quincenas', null),
        const Repeticion.meses(4),
      );
    });
  });
}
