import 'package:intl/intl.dart';

/// IGV peruano. Los precios de la app YA lo llevan adentro (ver
/// `CalculadoraTotales`); nunca se suma encima.
const double kIgv = 0.18;

/// Redondea a céntimos. Todo el dinero de la app pasa por aquí.
double redondear(num? n) => ((n ?? 0).toDouble() * 100).round() / 100;

const String _simbolo = 'S/ ';

/// El patrón va escrito a mano y anclado a `en_US` a propósito.
///
/// `NumberFormat.currency(locale: 'es_PE')` parece lo correcto, pero `intl`
/// solo trae compilados los datos de unos pocos locales: con `es_PE` cae en un
/// español genérico y termina imprimiendo `25,50 S/` —coma decimal y símbolo
/// al final—, que no es como se escribe la plata en Perú. El patrón de `en_US`
/// agrupa con coma y separa decimales con punto, que es exactamente el formato
/// peruano; lo único propio es el símbolo, y ese lo ponemos nosotros.
final NumberFormat _numero = NumberFormat('#,##0.00', 'en_US');

/// Formato de moneda para la interfaz y los documentos: `S/ 1,234.50`.
///
/// El signo va **antes** del símbolo (`-S/ 60.00`): es como se lee un
/// descuento en una boleta.
///
/// Con `simbolo: false` sale el número pelado, para las columnas de la boleta:
/// ahí el `S/` ya está en el encabezado y repetirlo en cada renglón solo
/// ensucia la columna.
String soles(num? n, {bool simbolo = true}) {
  final valor = (n ?? 0).toDouble();
  final signo = valor < 0 ? '-' : '';
  final marca = simbolo ? _simbolo : '';
  return '$signo$marca${_numero.format(valor.abs())}';
}

/// Lee un número escrito a mano: acepta coma o punto decimal y descarta el
/// resto. Un campo de precio en el celular recibe de todo.
double leerNumero(String? valor) {
  if (valor == null) return 0;
  final limpio = valor.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(limpio) ?? 0;
}
