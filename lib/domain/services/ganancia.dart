import '../../core/utils/dinero.dart';
import '../entities/trabajo.dart';

/// Lo que quedó de un trabajo, partido en dos: lo que dejó **tu mano de obra**
/// y lo que dejó **tu inventario**.
///
/// **La mano de obra y el traslado no restan.** El tiempo y la camioneta son
/// tuyos, no una factura que alguien te pasó: en un taller de una persona, lo
/// que se quiere saber es cuánta plata quedó después de reponer las piezas.
/// Por eso todo lo cobrado por trabajar es ganancia, y de los repuestos hay
/// que descontar lo que costó conseguirlos.
///
/// Es un número **interno**. No sale en la boleta ni en el reporte: el cliente
/// no tiene por qué ver cuánto se le ganó.
class Ganancia {
  const Ganancia({
    required this.cobradoMano,
    required this.cobradoRepuestos,
    required this.costo,
    required this.sinCosto,
  });

  /// Lo cobrado por trabajar —mano de obra y traslado—, ya con su parte del
  /// descuento restada.
  final double cobradoMano;

  /// Lo cobrado por las piezas, ya con su parte del descuento restada.
  final double cobradoRepuestos;

  /// Lo que costaron los repuestos que sí dicen cuánto costaron.
  final double costo;

  /// Cuántas líneas de repuesto no lo dicen.
  final int sinCosto;

  double get cobrado => redondear(cobradoMano + cobradoRepuestos);

  /// Trabajar no tiene costo de mercadería: lo cobrado es lo ganado.
  double get netaMano => cobradoMano;

  /// Lo que dejaron las piezas después de reponerlas. Puede dar negativo si
  /// se vendió algo por debajo de lo que costó.
  double get netaRepuestos => redondear(cobradoRepuestos - costo);

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
///
/// El descuento de la boleta se reparte **en proporción** entre las dos
/// mitades, con la misma regla que usa la boleta separada, y a los repuestos
/// se les asigna lo que falta para llegar al total: así las dos partes suman
/// exactamente lo que se cobró, sin un céntimo suelto.
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

  final tot = t.totales;
  final baseMano = redondear(tot.subTrabajos + tot.subTraslado);
  final descMano = tot.subtotal > 0
      ? redondear(tot.descuento * (baseMano / tot.subtotal))
      : 0.0;

  final cobradoMano = redondear(baseMano - descMano);

  return Ganancia(
    cobradoMano: cobradoMano,
    cobradoRepuestos: redondear(tot.total - cobradoMano),
    costo: redondear(costo),
    sinCosto: sinCosto,
  );
}
