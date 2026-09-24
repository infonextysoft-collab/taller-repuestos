import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';

void main() {
  group('con qué le pagan al negocio', () {
    test('sin nada cargado no hay qué imprimir', () {
      expect(const Negocio(nombre: 'Servicios MS').datosPago, isEmpty);
    });

    test('los tres datos salen rotulados y en orden', () {
      const n = Negocio(
        banco: 'BCP',
        cuenta: '191-0123456-0-12',
        cci: '00219100123456012',
        yape: '999888777',
      );

      expect(n.datosPago.map((d) => d.etiqueta).toList(),
          ['BCP', 'CCI', 'Yape']);
      expect(n.datosPago.first.valor, '191-0123456-0-12');
    });

    test('una cuenta sin banco se rotula "Cuenta"', () {
      const n = Negocio(cuenta: '191-0123456-0-12');

      expect(n.datosPago.single.etiqueta, 'Cuenta');
    });

    test('un banco sin número no sale solo: no dice nada', () {
      const n = Negocio(banco: 'BCP');

      expect(n.datosPago, isEmpty);
    });

    test('lo que es solo espacios cuenta como vacío', () {
      const n = Negocio(banco: '  ', cuenta: '   ', cci: ' 002191 ');

      expect(n.datosPago.single.etiqueta, 'CCI');
      expect(n.datosPago.single.valor, '002191');
    });
  });
}
