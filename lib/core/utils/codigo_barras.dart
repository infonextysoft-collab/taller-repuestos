/// Validación de códigos de barras.
///
/// Los códigos numéricos de 8, 12 y 13 dígitos (EAN-8, UPC-A, EAN-13) llevan
/// dígito verificador: revisarlo atrapa el error de tipeo antes de que quede
/// guardado y la búsqueda al vender deje de encontrar el repuesto.
///
/// Cualquier otro formato se acepta tal cual: hay etiquetas internas de taller
/// que no siguen ninguna norma, y bloquearlas sería inventar una regla que el
/// mundo real no tiene.
library;

/// La forma de un código para compararlo con otro.
///
/// Ignora mayúsculas y el cero de adelante de un EAN-13: un mismo producto
/// sale como UPC-A de 12 dígitos en un lector y como EAN-13 con un 0 delante
/// en otro, y son el mismo código.
String codigoParaComparar(String codigo) {
  final c = codigo.trim().toUpperCase();
  return RegExp(r'^0\d{12}$').hasMatch(c) ? c.substring(1) : c;
}

/// ¿El código es numérico de largo verificable?
bool esCodigoVerificable(String codigo) =>
    RegExp(r'^\d+$').hasMatch(codigo) &&
    const [8, 12, 13].contains(codigo.length);

/// Dígito verificador de un EAN/UPC a partir de sus dígitos sin el último.
int verificadorEan(String sinVerificador) {
  var suma = 0;
  final digitos = sinVerificador.split('').reversed.toList();

  for (var i = 0; i < digitos.length; i++) {
    final n = int.tryParse(digitos[i]) ?? 0;
    // Desde la derecha, las posiciones impares pesan 3 y las pares 1.
    suma += i.isEven ? n * 3 : n;
  }

  return (10 - (suma % 10)) % 10;
}

/// ¿El código cierra? Los formatos no verificables pasan siempre.
bool codigoBarrasValido(String? codigo) {
  final c = (codigo ?? '').trim();
  if (c.isEmpty) return true;
  if (!esCodigoVerificable(c)) return true;

  final esperado = verificadorEan(c.substring(0, c.length - 1));
  return (int.tryParse(c[c.length - 1]) ?? -1) == esperado;
}
