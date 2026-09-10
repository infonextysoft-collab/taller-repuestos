const _conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
const _sinTilde = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

/// Normaliza texto para buscar: sin espacios de sobra, sin mayúsculas y sin
/// tildes. Así "Bujía", "bujia" y "BUJIA" se encuentran entre sí.
String normalizar(String? texto) {
  final base = (texto ?? '').trim().toLowerCase();
  final buffer = StringBuffer();
  for (final c in base.split('')) {
    final i = _conTilde.indexOf(c);
    buffer.write(i >= 0 ? _sinTilde[i] : c);
  }
  return buffer.toString();
}

/// ¿`texto` contiene a `busqueda`, ignorando tildes y mayúsculas?
bool coincide(String? texto, String? busqueda) {
  final q = normalizar(busqueda);
  return q.isEmpty || normalizar(texto).contains(q);
}
