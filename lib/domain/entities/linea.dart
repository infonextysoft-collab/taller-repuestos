import '../../core/utils/dinero.dart';

/// Lo que toda línea tiene que saber contestar para poder ir a una tabla o a
/// un documento. Mano de obra y repuestos difieren en la cantidad, no en esto.
abstract class LineaDocumento {
  String get desc;
  double get precio;

  /// Cuántas unidades entran en el importe. La mano de obra siempre vale 1.
  num get cant;

  /// `cant × precio`, ya redondeado.
  double get importe => redondear(cant * precio);
}

/// Una línea de **mano de obra**.
///
/// No lleva cantidad a propósito: un trabajo no se cobra por unidades, se
/// cobra por lo que se acordó. Pedir "cantidad 1" en cada línea era un campo
/// que nadie cambiaba nunca y una pulsación más en el celular.
class LineaMano implements LineaDocumento {
  const LineaMano({required this.desc, required this.precio});

  @override
  final String desc;
  @override
  final double precio;

  @override
  num get cant => 1;

  @override
  double get importe => redondear(precio);

  LineaMano copyWith({String? desc, double? precio}) =>
      LineaMano(desc: desc ?? this.desc, precio: precio ?? this.precio);

  Map<String, dynamic> toJson() => {'desc': desc, 'precio': precio};

  factory LineaMano.fromJson(Map<String, dynamic> j) => LineaMano(
        desc: (j['desc'] ?? '').toString(),
        precio: (j['precio'] as num?)?.toDouble() ?? 0,
      );
}

/// De dónde salió un repuesto.
enum OrigenRepuesto { inventario, externo }

/// Una línea de **repuestos**. Acá la cantidad sí manda: mueve el stock.
class LineaRepuesto implements LineaDocumento {
  const LineaRepuesto({
    required this.desc,
    required this.cantidad,
    required this.precio,
    this.origen = OrigenRepuesto.externo,
    this.inventarioId,
    this.costo,
  });

  @override
  final String desc;
  final int cantidad;
  @override
  final double precio;
  final OrigenRepuesto origen;

  /// Solo tiene valor si [origen] es `inventario`.
  final int? inventarioId;

  /// Lo que costó **esta** unidad, congelado al cargarla.
  ///
  /// Se guarda en la línea y no se lee del inventario a la hora de mostrar la
  /// ganancia: si mañana sube el precio de compra, lo que se ganó ayer tiene
  /// que quedarse quieto. `null` es "no se sabe" —repuesto externo sin costo,
  /// o cargado antes de que existiera este campo—, y entonces la ganancia lo
  /// dice en vez de suponer cero.
  final double? costo;

  /// Lo que costaron todas las unidades de la línea.
  double? get costoTotal =>
      costo == null ? null : redondear(cantidad * costo!);

  @override
  num get cant => cantidad;

  bool get esDeInventario =>
      origen == OrigenRepuesto.inventario && inventarioId != null;

  @override
  double get importe => redondear(cantidad * precio);

  LineaRepuesto copyWith({
    String? desc,
    int? cantidad,
    double? precio,
    OrigenRepuesto? origen,
    int? inventarioId,
    double? costo,
  }) =>
      LineaRepuesto(
        desc: desc ?? this.desc,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
        origen: origen ?? this.origen,
        inventarioId: inventarioId ?? this.inventarioId,
        costo: costo ?? this.costo,
      );

  Map<String, dynamic> toJson() => {
        'desc': desc,
        'cant': cantidad,
        'precio': precio,
        'origen': origen.name,
        'inventarioId': inventarioId,
        'costo': costo,
      };

  factory LineaRepuesto.fromJson(Map<String, dynamic> j) => LineaRepuesto(
        desc: (j['desc'] ?? '').toString(),
        cantidad: (j['cant'] as num?)?.toInt() ?? 0,
        precio: (j['precio'] as num?)?.toDouble() ?? 0,
        origen: j['origen'] == 'inventario'
            ? OrigenRepuesto.inventario
            : OrigenRepuesto.externo,
        inventarioId: (j['inventarioId'] as num?)?.toInt(),
        costo: (j['costo'] as num?)?.toDouble(),
      );
}
