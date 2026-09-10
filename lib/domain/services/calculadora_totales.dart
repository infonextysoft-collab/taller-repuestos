import '../../core/utils/dinero.dart';
import '../entities/linea.dart';
import '../entities/totales.dart';
import '../entities/trabajo.dart';

/// Reglas de cálculo del sistema. Funciones puras: no tocan la base de datos
/// ni la interfaz, y son lo único que decide cuánta plata se cobra.
///
///   1. El IGV es 18% y **ya está incluido** en los precios que se cargan. El
///      impuesto no se suma encima: se desagrega del total solo para
///      mostrarlo, que es la formalidad que pide la boleta.
///   2. El traslado se cobra únicamente si el trabajo fue en campo **y** con
///      movilidad propia.
///   3. El traslado cuenta dentro de la mano de obra en la boleta separada.
///   4. El descuento se resta **antes** de desagregar el IGV, así el impuesto
///      sale sobre lo que realmente se cobró.
class CalculadoraTotales {
  const CalculadoraTotales();

  /// Suma los importes de un grupo de líneas.
  double sumarLineas(Iterable<LineaDocumento> lineas) =>
      redondear(lineas.fold<double>(0, (acc, l) => acc + l.cant * l.precio));

  /// Cuánto se cobra de traslado.
  ///
  /// Exige **las dos** condiciones. Mirar solo la movilidad no alcanza: si
  /// alguien elige Campo, carga las vueltas y después vuelve a Taller, esos
  /// datos quedan guardados y el traslado se cobraría en un trabajo que nunca
  /// salió del taller.
  double calcularTraslado(Trabajo t) {
    if (t.tipo != TipoTrabajo.campo) return 0;
    if (t.movilidad != Movilidad.propia) return 0;
    return redondear(t.vueltas * t.precioVuelta);
  }

  /// Totales de un registro completo (venta o trabajo).
  Totales calcular(Trabajo t) {
    final subTrabajos = sumarLineas(t.trabajosRealizados);
    final subRepuestos = sumarLineas(t.repuestos);
    final subTraslado = calcularTraslado(t);

    final subtotal = redondear(subTrabajos + subRepuestos + subTraslado);

    // El descuento nunca puede dejar el total en negativo.
    final descuento = redondear(t.descuento.clamp(0, subtotal));

    // Esto es lo que paga el cliente: el IGV ya está adentro.
    final total = redondear(subtotal - descuento);

    // Desagregado, solo para mostrarlo. El IGV sale por diferencia para que
    // `gravado + igv == total` siempre, sin un céntimo suelto.
    final gravado = redondear(total / (1 + kIgv));
    final igv = redondear(total - gravado);

    return Totales(
      subTrabajos: subTrabajos,
      subRepuestos: subRepuestos,
      subTraslado: subTraslado,
      subtotal: subtotal,
      descuento: descuento,
      gravado: gravado,
      igv: igv,
      total: total,
    );
  }

  /// La(s) boleta(s) según el modo elegido en el último paso.
  ///
  /// En modo separado el descuento se reparte proporcionalmente y el céntimo
  /// que sobra al redondear se le asigna a la segunda, igual que su IGV: así
  /// las dos boletas suman **exactamente** el mismo total y el mismo impuesto
  /// que la boleta junta. Si se calculan por separado, los papeles no cuadran.
  List<Boleta> calcularBoletas(Trabajo t) {
    final tot = calcular(t);

    if (t.vistaDoc != VistaDoc.separado) {
      return [
        Boleta(
          titulo: 'Boleta',
          subtotal: tot.subtotal,
          descuento: tot.descuento,
          gravado: tot.gravado,
          igv: tot.igv,
          total: tot.total,
        ),
      ];
    }

    // El traslado viaja con la mano de obra.
    final baseMO = redondear(tot.subTrabajos + tot.subTraslado);
    final baseRep = tot.subRepuestos;

    final descMO = tot.subtotal > 0
        ? redondear(tot.descuento * (baseMO / tot.subtotal))
        : 0.0;
    final descRep = redondear(tot.descuento - descMO);

    final totalMO = redondear(baseMO - descMO);
    final totalRep = redondear(baseRep - descRep);

    final gravadoMO = redondear(totalMO / (1 + kIgv));
    final igvMO = redondear(totalMO - gravadoMO);

    final igvRep = redondear(tot.igv - igvMO);
    final gravadoRep = redondear(totalRep - igvRep);

    return [
      Boleta(
        titulo: 'Boleta de Mano de Obra',
        subtotal: baseMO,
        descuento: descMO,
        gravado: gravadoMO,
        igv: igvMO,
        total: totalMO,
        incluyeRepuestos: false,
      ),
      Boleta(
        titulo: 'Boleta de Repuestos',
        subtotal: baseRep,
        descuento: descRep,
        gravado: gravadoRep,
        igv: igvRep,
        total: totalRep,
        incluyeManoDeObra: false,
      ),
    ];
  }
}

/// Instancia única: la calculadora no tiene estado.
const calculadora = CalculadoraTotales();
