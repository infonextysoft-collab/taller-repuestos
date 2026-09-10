/// Monto en letras para los documentos:
/// `"SON: SEISCIENTOS NOVENTA Y SIETE CON 00/100 SOLES"`.
///
/// En Perú cualquier comprobante lo lleva. Además sirve de control: si alguien
/// retoca el número a mano, las letras lo delatan.
library;

const List<String> _unidades = [
  '', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE',
  'DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE', 'DIECISEIS',
  'DIECISIETE', 'DIECIOCHO', 'DIECINUEVE', 'VEINTE',
];

const List<String> _decenas = [
  '', '', 'VEINTI', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA',
  'OCHENTA', 'NOVENTA',
];

const List<String> _centenas = [
  '', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS',
  'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS',
];

/// Convierte 0-999 a palabras.
String _tresCifras(int n) {
  if (n == 0) return '';
  if (n == 100) return 'CIEN';

  final c = n ~/ 100;
  final resto = n % 100;
  final partes = <String>[];

  if (c > 0) partes.add(_centenas[c]);

  if (resto > 0) {
    if (resto <= 20) {
      partes.add(_unidades[resto]);
    } else {
      final d = resto ~/ 10;
      final u = resto % 10;
      if (d == 2) {
        // VEINTIUNO, VEINTIDOS... van pegados; VEINTE entra por resto <= 20.
        partes.add('VEINTI${_unidades[u]}');
      } else if (u == 0) {
        partes.add(_decenas[d]);
      } else {
        partes.add('${_decenas[d]} Y ${_unidades[u]}');
      }
    }
  }

  return partes.join(' ');
}

/// Parte entera a palabras. Cubre hasta millones.
String enteroEnLetras(int n) {
  if (n == 0) return 'CERO';

  final millones = n ~/ 1000000;
  final miles = (n % 1000000) ~/ 1000;
  final resto = n % 1000;
  final partes = <String>[];

  if (millones > 0) {
    partes.add(millones == 1 ? 'UN MILLON' : '${_tresCifras(millones)} MILLONES');
  }
  if (miles > 0) {
    partes.add(miles == 1 ? 'MIL' : '${_tresCifras(miles)} MIL');
  }
  if (resto > 0) partes.add(_tresCifras(resto));

  return partes.join(' ');
}

/// `montoEnLetras(697)` → `"SON: SEISCIENTOS NOVENTA Y SIETE CON 00/100 SOLES"`
String montoEnLetras(num? monto, {String moneda = 'SOLES'}) {
  final valor = (monto ?? 0).abs().toDouble();
  // Se redondea a céntimos ANTES de partir, o 0.999 daría "CERO CON 100/100".
  final centimos = (valor * 100).round();
  final entero = centimos ~/ 100;
  final decimales = centimos % 100;

  return 'SON: ${enteroEnLetras(entero)} CON '
      '${decimales.toString().padLeft(2, '0')}/100 $moneda';
}
