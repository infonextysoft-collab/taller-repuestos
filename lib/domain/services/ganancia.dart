import '../../core/utils/dinero.dart';
import '../entities/trabajo.dart';

/// Lo que quedó de un trabajo: lo cobrado menos lo que costaron los repuestos.
///
/// **La mano de obra y el traslado no restan.** El tiempo y la camioneta son
/// tuyos, no una factura que alguien te pasó: en un taller de una persona, lo
/// que se quiere saber es cuánta plata quedó después de reponer las piezas.
///
/// Es un número **interno**. No sale en la boleta ni en el reporte: el cliente
/// no tiene por qué ver cuánto se le ganó.
class Ganancia {
  const Ganancia({
    required this.cobrado,
    required this.costo,
    required this.sinCosto,
  });

  final double cobrado;

  /// Lo que costaron los repuestos que sí dicen cuánto costaron.
  final double costo;

  /// Cuántas líneas de repuesto no lo dicen.
  final int sinCosto;

  double get neta => redondear(cobrado - costo);

  /// Con líneas mudas, [neta] es un techo y no la ganancia real: falta
  /// restar lo que costaron esas. Quien la muestre tiene que avisarlo.
  bool get completa => sinCosto == 0;

  /// En porcentaje de lo cobrado. `null` si no se cobró nada.
  double? get porcentaje => cobrado <= 0 ? null : neta / cobrado * 100;
}

/// Suma lo que costaron los repuestos de [t] y lo resta de lo cobrado.
///
/// Nunca supone que un repuesto sin costo salió gratis: lo cuenta aparte, y
/// así la diferencia entre "gané 380" y "gané 380 y hay 2 que no sé cuánto
/// costaron" queda a la vista.
Ganancia gananciaDe(Trabajo t) {
  var costo = 0.0;
  var sinCosto = 0;

  for (final linea in t.repuestos) {
    final total = linea.costoTotal;
    if (total == null) {
      sinCosto++;
    } else {
      costo += total;
    }
  }

  return Ganancia(
    cobrado: t.totales.total,
    costo: redondear(costo),
    sinCosto: sinCosto,
  );
}
