/// Fechas en formato ISO corto (`"2026-08-25"`), sin hora y sin zona horaria:
/// a la app solo le importa el día, y usar timestamps mueve el día de más de un
/// usuario según la hora a la que abra la app.
library;

const List<String> _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _dos(int n) => n.toString().padLeft(2, '0');

/// Hoy en ISO corto, en hora local.
String hoyISO() {
  final d = DateTime.now();
  return '${d.year}-${_dos(d.month)}-${_dos(d.day)}';
}

/// ISO corto de un [DateTime] cualquiera.
String isoDe(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

/// ISO corto → [DateTime] local (mediodía, para no rozar cambios de horario).
DateTime fechaDe(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(p[0]) ?? DateTime.now().year,
    int.tryParse(p[1]) ?? 1,
    int.tryParse(p[2]) ?? 1,
  );
}

/// Suma meses a una fecha ISO. Si el día no existe en el mes destino
/// (31 de enero + 1 mes), cae al **último día de ese mes** en vez de saltar al
/// siguiente.
String sumarMeses(String fechaISO, int meses) {
  final p = fechaISO.split('-');
  final a = int.tryParse(p.elementAt(0)) ?? DateTime.now().year;
  final m = p.length > 1 ? (int.tryParse(p[1]) ?? 1) : 1;
  final d = p.length > 2 ? (int.tryParse(p[2]) ?? 1) : 1;

  final destino = DateTime(a, m + meses, 1);
  final ultimoDia = DateTime(destino.year, destino.month + 1, 0).day;
  final dia = d < ultimoDia ? d : ultimoDia;

  return '${destino.year}-${_dos(destino.month)}-${_dos(dia)}';
}

/// Suma días a una fecha ISO. `DateTime` normaliza solo el desborde de mes.
String sumarDias(String fechaISO, int dias) =>
    isoDe(fechaDe(fechaISO).add(Duration(days: dias)));

/// ¿La fecha ya pasó? Hoy mismo todavía **no** está vencido.
bool estaVencida(String fechaISO) => fechaISO.compareTo(hoyISO()) < 0;

/// `"2026-08-25"` → `"25/08/2026"`
String formatoCorto(String fechaISO) {
  final p = fechaISO.split('-');
  if (p.length != 3) return fechaISO;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// `"2026-08-25"` → `"25 de agosto de 2026"`
String formatoLargo(String fechaISO) {
  final p = fechaISO.split('-');
  if (p.length != 3) return fechaISO;
  final m = int.tryParse(p[1]) ?? 1;
  final d = int.tryParse(p[2]) ?? 1;
  return '$d de ${_meses[m - 1].toLowerCase()} de ${p[0]}';
}

/// `"2026-08"` → `"Agosto 2026"` — encabezado de los grupos de Recordatorios.
String nombreMes(String claveDeMes) {
  final p = claveDeMes.split('-');
  if (p.length < 2) return claveDeMes;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_meses[m - 1]} ${p[0]}';
}

/// Clave de agrupación por mes: `"2026-08-25"` → `"2026-08"`
String claveMes(String fechaISO) =>
    fechaISO.length >= 7 ? fechaISO.substring(0, 7) : fechaISO;

const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// `"2026-11-06"` → `"6 nov"`. Si es de otro año, lo dice: `"6 nov 2025"`.
String diaMes(String fechaISO, {String? hoy}) {
  final p = fechaISO.split('-');
  if (p.length != 3) return fechaISO;

  final m = int.tryParse(p[1]) ?? 1;
  final d = int.tryParse(p[2]) ?? 1;
  final texto = '$d ${_mesesCortos[m - 1]}';

  return p[0] == (hoy ?? hoyISO()).split('-').first ? texto : '$texto ${p[0]}';
}

/// Días que faltan para esa fecha: negativo si ya pasó, `0` si es hoy.
///
/// En UTC a propósito: un día de 23 horas por cambio de horario restaría mal.
int diasHasta(String fechaISO, {String? hoy}) {
  DateTime utc(String iso) {
    final f = fechaDe(iso);
    return DateTime.utc(f.year, f.month, f.day);
  }

  return utc(fechaISO).difference(utc(hoy ?? hoyISO())).inDays;
}

String _cuantoFalta(int dias) {
  if (dias < 14) return dias == 1 ? '1 día' : '$dias días';
  if (dias < 60) return '${dias ~/ 7} semanas';
  if (dias < 365) return '${dias ~/ 30} meses';
  return dias < 730 ? '1 año' : '${dias ~/ 365} años';
}

/// La fecha de un aviso como se diría en voz alta:
/// `"Venció hace 3 días · 6 nov"`, `"Hoy · 9 nov"`, `"En 3 semanas · 30 nov"`.
String fechaEnPalabras(String fechaISO, {String? hoy}) {
  final d = diasHasta(fechaISO, hoy: hoy);

  final cuando = switch (d) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Venció ayer',
    < 0 => 'Venció hace ${_cuantoFalta(-d)}',
    _ => 'En ${_cuantoFalta(d)}',
  };

  return '$cuando · ${diaMes(fechaISO, hoy: hoy)}';
}
