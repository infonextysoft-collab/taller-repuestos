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

/// Un correo a medio tapar, para mostrarlo sin exponerlo entero:
/// `wilmer73@gmail.com` → `wi•••••@gmail.com`.
///
/// Deja ver lo justo para reconocer cuál es —el comienzo y el dominio— y no
/// lo suficiente para que alguien que mira la pantalla lo anote. Los puntos
/// son siempre cinco: contarlos no delata el largo.
String ocultarCorreo(String correo) {
  final limpio = correo.trim();
  if (limpio.isEmpty) return '';

  final arroba = limpio.lastIndexOf('@');
  if (arroba <= 0) return '•••••';

  final usuario = limpio.substring(0, arroba);
  // Con dos letras o menos, mostrar dos sería mostrarlo entero.
  final visible = usuario.substring(0, usuario.length <= 2 ? 1 : 2);
  return '$visible•••••${limpio.substring(arroba)}';
}
