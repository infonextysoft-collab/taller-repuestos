import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/codigo_barras.dart';
import 'package:taller_repuestos/core/utils/dinero.dart';
import 'package:taller_repuestos/core/utils/documento.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/core/utils/letras.dart';
import 'package:taller_repuestos/core/utils/texto.dart';

void main() {
  group('fechas', () {
    test('sumarMeses cae al último día si el destino no lo tiene', () {
      // 31 de enero + 1 mes es 28 de febrero, no el 3 de marzo.
      expect(sumarMeses('2026-01-31', 1), '2026-02-28');
      expect(sumarMeses('2024-01-31', 1), '2024-02-29');
      expect(sumarMeses('2026-08-25', 6), '2027-02-25');
    });

    test('sumarMeses cruza el año', () {
      expect(sumarMeses('2026-11-15', 3), '2027-02-15');
    });

    test('hoy todavía no está vencido', () {
      expect(estaVencida(hoyISO()), isFalse);
      expect(estaVencida(sumarMeses(hoyISO(), -1)), isTrue);
      expect(estaVencida(sumarMeses(hoyISO(), 1)), isFalse);
    });

    test('formatos', () {
      expect(formatoCorto('2026-08-25'), '25/08/2026');
      expect(formatoLargo('2026-08-25'), '25 de agosto de 2026');
      expect(nombreMes('2026-08'), 'Agosto 2026');
      expect(claveMes('2026-08-25'), '2026-08');
    });
  });

  group('documento', () {
    test('RUCs reales pasan', () {
      // Verificados contra RUCs que existen.
      expect(revisarDocumento('20131312955').estado, EstadoDocumento.valido);
      expect(revisarDocumento('20100047218').estado, EstadoDocumento.valido);
    });

    test('cambiarle un dígito a un RUC lo invalida', () {
      expect(revisarDocumento('20131312954').estado, EstadoDocumento.invalido);
    });

    test('escribir a medias no es un error', () {
      // Marcar en rojo mientras la persona teclea la entrena a ignorar todos
      // los avisos.
      expect(revisarDocumento('204').estado, EstadoDocumento.escribiendo);
      expect(revisarDocumento('204').tipo, TipoDocumento.ruc);
      expect(revisarDocumento('204').aceptable, isTrue);
    });

    test('vacío es válido: el campo es opcional', () {
      expect(revisarDocumento('').estado, EstadoDocumento.vacio);
      expect(documentoAceptable(''), isTrue);
    });

    test('ocho dígitos sin prefijo de RUC son un DNI', () {
      final r = revisarDocumento('12345678');
      expect(r.estado, EstadoDocumento.valido);
      expect(r.tipo, TipoDocumento.dni);
    });

    test('un prefijo que no existe se rechaza cuando está completo', () {
      expect(revisarDocumento('30131312955').estado, EstadoDocumento.invalido);
    });

    test('soloRuc no acepta un DNI', () {
      final r = revisarDocumento('12345678', soloRuc: true);
      expect(r.tipo, TipoDocumento.ruc);
      expect(r.estado, EstadoDocumento.escribiendo);
    });

    test('soloDigitos limpia lo pegado', () {
      expect(soloDigitos('20-13a1'), '20131');
    });
  });

  group('monto en letras', () {
    test('casos que rompen las implementaciones ingenuas', () {
      expect(montoEnLetras(0), 'SON: CERO CON 00/100 SOLES');
      expect(montoEnLetras(20), 'SON: VEINTE CON 00/100 SOLES');
      expect(montoEnLetras(21), 'SON: VEINTIUNO CON 00/100 SOLES');
      expect(montoEnLetras(100), 'SON: CIEN CON 00/100 SOLES');
      expect(montoEnLetras(101), 'SON: CIENTO UNO CON 00/100 SOLES');
      expect(montoEnLetras(1000), 'SON: MIL CON 00/100 SOLES');
      expect(montoEnLetras(1000000), 'SON: UN MILLON CON 00/100 SOLES');
    });

    test('el caso de la boleta', () {
      expect(
        montoEnLetras(697),
        'SON: SEISCIENTOS NOVENTA Y SIETE CON 00/100 SOLES',
      );
    });

    test('redondea a céntimos antes de partir', () {
      // Sin redondear primero, 0.999 daría "CERO CON 100/100".
      expect(montoEnLetras(0.999), 'SON: UNO CON 00/100 SOLES');
      expect(montoEnLetras(1234567.89).endsWith('CON 89/100 SOLES'), isTrue);
    });
  });

  group('moneda', () {
    test('formato peruano: símbolo delante, punto decimal, coma de miles', () {
      // `NumberFormat.currency(locale: 'es_PE')` imprimía "25,50 S/" porque
      // intl no trae ese local compilado y caía en un español genérico.
      expect(soles(25.5), 'S/ 25.50');
      expect(soles(697), 'S/ 697.00');
      expect(soles(1234.5), 'S/ 1,234.50');
      expect(soles(0), 'S/ 0.00');
      expect(soles(null), 'S/ 0.00');
    });

    test('el signo va antes del símbolo, como en una boleta', () {
      expect(soles(-60), '-S/ 60.00');
    });

    test('leerNumero acepta coma o punto', () {
      expect(leerNumero('25,50'), 25.5);
      expect(leerNumero('25.50'), 25.5);
      expect(leerNumero('S/ 1.20'), 1.2);
      expect(leerNumero(''), 0);
      expect(leerNumero(null), 0);
    });
  });

  group('texto', () {
    test('la búsqueda ignora tildes y mayúsculas', () {
      expect(coincide('Bujía NGK', 'bujia'), isTrue);
      expect(coincide('BUJIA', 'Bují'), isTrue);
      expect(coincide('Rodamiento', 'buji'), isFalse);
    });

    test('buscar vacío devuelve todo', () {
      expect(coincide('lo que sea', ''), isTrue);
    });
  });

  group('código de barras', () {
    test('un EAN-13 con su verificador cierra', () {
      expect(codigoBarrasValido('7501234567893'), isTrue);
    });

    test('con el verificador cambiado, no', () {
      expect(codigoBarrasValido('7501234567890'), isFalse);
    });

    test('los formatos no verificables pasan tal cual', () {
      // Etiquetas internas de taller: no siguen ninguna norma, y bloquearlas
      // sería inventar una regla que el mundo real no tiene.
      expect(codigoBarrasValido('ABC-123'), isTrue);
      expect(codigoBarrasValido('12345'), isTrue);
      expect(codigoBarrasValido(''), isTrue);
    });
  });
}
