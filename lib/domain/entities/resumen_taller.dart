import '../../core/utils/fechas.dart';
import 'recordatorio.dart';
import 'repuesto.dart';
import 'trabajo.dart';

/// Lo que hay que atender, en un solo objeto.
///
/// La app no es un tablero de negocio: es un técnico solo, parado en el taller.
/// Por eso este resumen **no lleva plata**. Junta las tres cosas que de verdad
/// le cuestan algo si se le pasan:
///
///   1. Un mantenimiento que le toca a un cliente hoy — trabajo que vuelve.
///   2. Un registro que empezó y no cerró — trabajo hecho sin papel.
///   3. Un repuesto agotado — enterarse con el equipo ya abierto es tarde.
class ResumenTaller {
  const ResumenTaller({
    this.pendientesHoy = const [],
    this.sinCerrar = const [],
    this.sinStock = const [],
    this.proximoMantenimiento,
  });

  /// Mantenimientos vencidos **y** los de hoy, juntos y de más viejo a más
  /// nuevo. Un vencido no deja de ser cosa de hoy por haber pasado de fecha:
  /// es lo primero que hay que resolver.
  final List<Recordatorio> pendientesHoy;

  /// Registros a medias, del más viejo al más nuevo: el que lleva más tiempo
  /// abierto es el que más riesgo tiene de quedar sin documento.
  final List<Trabajo> sinCerrar;

  final List<Repuesto> sinStock;

  /// La próxima fecha agendada, ya en el futuro. Solo se usa cuando no hay
  /// nada pendiente, para que la tarjeta de "al día" diga algo útil.
  final String? proximoMantenimiento;

  bool get alDia =>
      pendientesHoy.isEmpty && sinCerrar.isEmpty && sinStock.isEmpty;

  /// Arma el resumen a partir de lo que devuelve cada repositorio.
  factory ResumenTaller.de({
    required List<Recordatorio> recordatorios,
    required List<Trabajo> trabajos,
    required List<Repuesto> inventario,
  }) {
    final hoy = hoyISO();

    final vencenHoy = recordatorios
        .where((r) => !r.cumplido && r.fecha.compareTo(hoy) <= 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final futuros = recordatorios
        .where((r) => !r.cumplido && r.fecha.compareTo(hoy) > 0)
        .map((r) => r.fecha)
        .toList()
      ..sort();

    final abiertos = trabajos.where((t) => !t.estaTerminado).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return ResumenTaller(
      pendientesHoy: vencenHoy,
      sinCerrar: abiertos,
      sinStock: inventario.where((r) => r.agotado).toList(),
      proximoMantenimiento: futuros.isEmpty ? null : futuros.first,
    );
  }
}
