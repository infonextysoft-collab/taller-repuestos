import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/validacion.dart';

void main() {
  group('obligatorio', () {
    final validar = Valida.obligatorio('el nombre del cliente');

    test('vacío o solo espacios no pasa', () {
      expect(validar(''), 'Falta el nombre del cliente.');
      expect(validar('   '), 'Falta el nombre del cliente.');
      expect(validar(null), 'Falta el nombre del cliente.');
    });

    test('con contenido pasa', () => expect(validar('Ana'), isNull));
  });

  group('documento', () {
    final validar = Valida.documento();

    test('vacío pasa: el campo es opcional', () {
      expect(validar(''), isNull);
    });

    test('a medio escribir no deja guardar', () {
      // Mientras se teclea se muestra como ayuda gris; recién al guardar
      // bloquea, porque termina impreso en la boleta.
      expect(validar('204'), isNotNull);
    });

    test('un RUC real pasa y uno con un dígito cambiado no', () {
      expect(validar('20131312955'), isNull);
      expect(validar('20131312954'), isNotNull);
    });

    test('con soloRuc, un DNI no alcanza', () {
      expect(Valida.documento(soloRuc: true)('12345678'), isNotNull);
    });
  });

  group('email', () {
    final validar = Valida.email();

    test('vacío pasa', () => expect(validar(''), isNull));

    test('direcciones razonables pasan', () {
      expect(validar('taller@correo.com'), isNull);
      expect(validar('servicios.tech@gmail.com.pe'), isNull);
    });

    test('lo que claramente no es un correo, no', () {
      expect(validar('taller'), isNotNull);
      expect(validar('taller@'), isNotNull);
      expect(validar('taller@correo'), isNotNull);
      expect(validar('a b@correo.com'), isNotNull);
    });
  });

  group('teléfono', () {
    final validar = Valida.telefono();

    test('vacío pasa', () => expect(validar(''), isNull));

    test('acepta separadores', () {
      expect(validar('999 999 999'), isNull);
      expect(validar('(01) 555-1234'), isNull);
    });

    test('rechaza lo muy corto y lo muy largo', () {
      expect(validar('123'), isNotNull);
      expect(validar('1234567890123'), isNotNull);
    });
  });

  group('precio', () {
    test('vacío pasa si es opcional y no si es obligatorio', () {
      expect(Valida.precio()(''), isNull);
      expect(Valida.precio(obligatorio: true)(''), 'Falta el precio.');
    });

    test('acepta coma o punto', () {
      expect(Valida.precio()('25,50'), isNull);
      expect(Valida.precio()('25.50'), isNull);
    });

    test('rechaza texto, negativos y cifras absurdas', () {
      expect(Valida.precio()('abc'), isNotNull);
      expect(Valida.precio()('-5'), isNotNull);
      expect(Valida.precio()('9999999'), isNotNull);
    });
  });

  group('entero', () {
    test('respeta el mínimo', () {
      final validar = Valida.entero(obligatorio: true, minimo: 1);
      expect(validar('0'), isNotNull);
      expect(validar('1'), isNull);
    });

    test('rechaza lo que no es un entero', () {
      expect(Valida.entero()('2.5'), isNotNull);
    });
  });

  group('descuento', () {
    test('no puede superar el subtotal', () {
      final validar = Valida.descuento(() => 100);
      expect(validar('50'), isNull);
      expect(validar('100'), isNull);
      expect(validar('101'), 'El descuento no puede superar el subtotal.');
    });

    test('sigue el subtotal del momento, no uno congelado', () {
      var subtotal = 50.0;
      final validar = Valida.descuento(() => subtotal);

      expect(validar('80'), isNotNull);
      subtotal = 100;
      expect(validar('80'), isNull);
    });
  });

  group('encadenado', () {
    test('devuelve el primer error, en orden', () {
      // Primero "falta", después "está mal escrito": decirle a alguien que su
      // dato tiene mal formato cuando todavía no escribió nada es ruido.
      final validar = Valida.todos([
        Valida.obligatorio('el RUC'),
        Valida.documento(soloRuc: true),
      ]);

      expect(validar(''), 'Falta el RUC.');
      expect(validar('204'), isNot('Falta el RUC.'));
      expect(validar('20131312955'), isNull);
    });
  });
}
