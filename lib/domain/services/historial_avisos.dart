import '../../core/utils/fechas.dart';
import '../entities/recordatorio.dart';

/// Lo que pasó con los avisos de un mes.
///
/// Un aviso cuenta en el mes de su **fecha programada**, no en el día en que
/// se atendió: el de octubre que se resuelve en noviembre sube el avance de
/// octubre, que es el mes que estaba debiendo. Cada vez que uno se repite es
/// un aviso aparte y cuenta aparte.
class MesDeAvisos {
  const MesDeAvisos({
    required this.clave,
    required this.cumplidos,
    required this.sinCumplir,
    required this.eliminados,
  });

  /// `"2026-11"`.
  final String clave;
  final List<Recordatorio> cumplidos;

  /// Ya pasó la fecha y nadie lo marcó. Lo que todavía no llegó no entra: no
  /// se puede deber lo que aún no toca.
  final List<Recordatorio> sinCumplir;

  /// Se ven en la lista del mes, pero **no cuentan** en el "X de Y".
  final List<Recordatorio> eliminados;

  int get cuantos => cumplidos.length + sinCumplir.length;
  double get avance => cuantos == 0 ? 0 : cumplidos.length / cuantos;
}

int _anioDe(String fechaISO) => int.tryParse(fechaISO.split('-').first) ?? 0;

bool _sinCumplir(Recordatorio r, String hoy) =>
    r.activo && r.fecha.compareTo(hoy) < 0;

bool _vaAlHistorial(Recordatorio r, String hoy) =>
    r.cumplido || r.eliminado || _sinCumplir(r, hoy);

/// Los años que tienen algo que mostrar, del más nuevo al más viejo.
///
/// El año en curso está siempre: es donde se abre la pantalla, aunque en
/// enero todavía no tenga nada.
List<int> aniosDelHistorial(List<Recordatorio> todos, {String? hoy}) {
  final dia = hoy ?? hoyISO();

  final anios = <int>{
    _anioDe(dia),
    for (final r in todos)
      if (_vaAlHistorial(r, dia)) _anioDe(r.fecha),
  };

  return anios.toList()..sort((a, b) => b.compareTo(a));
}

/// El número de la ficha: lo cumplido de ese año.
int cumplidosDelAnio(List<Recordatorio> todos, int anio) =>
    todos.where((r) => r.cumplido && _anioDe(r.fecha) == anio).length;

/// Los meses con algo que mostrar, del más nuevo al más viejo.
List<MesDeAvisos> mesesDelAnio(
  List<Recordatorio> todos,
  int anio, {
  String? hoy,
}) {
  final dia = hoy ?? hoyISO();
  final porMes = <String, List<Recordatorio>>{};

  for (final r in todos) {
    if (_anioDe(r.fecha) == anio && _vaAlHistorial(r, dia)) {
      porMes.putIfAbsent(claveMes(r.fecha), () => []).add(r);
    }
  }

  final claves = porMes.keys.toList()..sort((a, b) => b.compareTo(a));

  return [
    for (final clave in claves)
      () {
        final items = porMes[clave]!
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

        return MesDeAvisos(
          clave: clave,
          cumplidos: items.where((r) => r.cumplido).toList(),
          sinCumplir: items.where((r) => _sinCumplir(r, dia)).toList(),
          eliminados: items.where((r) => r.eliminado).toList(),
        );
      }(),
  ];
}
