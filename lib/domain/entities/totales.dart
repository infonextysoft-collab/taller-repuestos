/// Resultado de las reglas de cálculo. Inmutable a propósito: se calcula de
/// una sola forma y se guarda congelado en el registro terminado.
class Totales {
  const Totales({
    this.subTrabajos = 0,
    this.subRepuestos = 0,
    this.subTraslado = 0,
    this.subtotal = 0,
    this.descuento = 0,
    this.gravado = 0,
    this.igv = 0,
    this.total = 0,
  });

  final double subTrabajos;
  final double subRepuestos;
  final double subTraslado;
  final double subtotal;
  final double descuento;

  /// Base imponible: `total / 1.18`. Solo se muestra, no se suma.
  final double gravado;

  /// IGV **ya incluido** en el total, sacado por diferencia.
  final double igv;
  final double total;

  Map<String, dynamic> toJson() => {
        'subTrabajos': subTrabajos,
        'subRepuestos': subRepuestos,
        'subTraslado': subTraslado,
        'subtotal': subtotal,
        'descuento': descuento,
        'gravado': gravado,
        'igv': igv,
        'total': total,
      };

  factory Totales.fromJson(Map<String, dynamic> j) => Totales(
        subTrabajos: (j['subTrabajos'] as num?)?.toDouble() ?? 0,
        subRepuestos: (j['subRepuestos'] as num?)?.toDouble() ?? 0,
        subTraslado: (j['subTraslado'] as num?)?.toDouble() ?? 0,
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        descuento: (j['descuento'] as num?)?.toDouble() ?? 0,
        gravado: (j['gravado'] as num?)?.toDouble() ?? 0,
        igv: (j['igv'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Una boleta: puede ser la única, o una de las dos del modo separado.
class Boleta {
  const Boleta({
    required this.titulo,
    required this.subtotal,
    required this.descuento,
    required this.gravado,
    required this.igv,
    required this.total,
    this.incluyeManoDeObra = true,
    this.incluyeRepuestos = true,
  });

  final String titulo;
  final double subtotal;
  final double descuento;
  final double gravado;
  final double igv;
  final double total;

  /// Qué secciones dibuja esta boleta. En el modo junto, las dos.
  final bool incluyeManoDeObra;
  final bool incluyeRepuestos;
}
