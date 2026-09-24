import 'dart:convert';

import '../../core/utils/dinero.dart';

/// Un renglón de una compra: qué repuesto entró, cuántas unidades y a cuánto.
class LineaCompra {
  const LineaCompra({
    required this.desc,
    required this.cantidad,
    required this.costo,
    this.inventarioId,
  });

  final String desc;
  final int cantidad;

  /// Lo que costó cada unidad en **esta** compra.
  final double costo;

  /// El repuesto del inventario al que le entran las unidades. Sin esto la
  /// línea queda como registro histórico y no mueve stock.
  final int? inventarioId;

  double get importe => redondear(cantidad * costo);

  LineaCompra copyWith({String? desc, int? cantidad, double? costo}) =>
      LineaCompra(
        desc: desc ?? this.desc,
        cantidad: cantidad ?? this.cantidad,
        costo: costo ?? this.costo,
        inventarioId: inventarioId,
      );

  Map<String, dynamic> toJson() => {
        'desc': desc,
        'cant': cantidad,
        'costo': costo,
        'inventarioId': inventarioId,
      };

  factory LineaCompra.fromJson(Map<String, dynamic> j) => LineaCompra(
        desc: (j['desc'] ?? '').toString(),
        cantidad: (j['cant'] as num?)?.toInt() ?? 0,
        costo: (j['costo'] as num?)?.toDouble() ?? 0,
        inventarioId: (j['inventarioId'] as num?)?.toInt(),
      );
}

/// Lo que se le compró a un proveedor: de acá sale el stock.
///
/// El proveedor y la boleta son **opcionales** a propósito. La mitad de las
/// compras de un taller son en efectivo y sin papel; exigirlos haría que
/// nadie registre nada, y una compra sin proveedor sigue siendo mejor que
/// ninguna.
class Compra {
  const Compra({
    this.id,
    required this.fecha,
    this.proveedor = '',
    this.boleta = '',
    this.lineas = const [],
  });

  final int? id;

  /// ISO corto, sin hora ni zona horaria. Igual que en los trabajos.
  final String fecha;

  final String proveedor;
  final String boleta;
  final List<LineaCompra> lineas;

  /// Se calcula, no se guarda: un total guardado se pelea con sus renglones
  /// apenas alguien toca uno.
  double get total =>
      redondear(lineas.fold<double>(0, (suma, l) => suma + l.importe));

  int get unidades => lineas.fold<int>(0, (suma, l) => suma + l.cantidad);

  Compra copyWith({
    String? fecha,
    String? proveedor,
    String? boleta,
    List<LineaCompra>? lineas,
  }) =>
      Compra(
        id: id,
        fecha: fecha ?? this.fecha,
        proveedor: proveedor ?? this.proveedor,
        boleta: boleta ?? this.boleta,
        lineas: lineas ?? this.lineas,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'fecha': fecha,
        'proveedor': proveedor.trim(),
        'boleta': boleta.trim(),
        'detalle': jsonEncode(lineas.map((l) => l.toJson()).toList()),
      };

  factory Compra.fromRow(Map<String, Object?> r) => Compra(
        id: (r['id'] as num?)?.toInt(),
        fecha: (r['fecha'] ?? '').toString(),
        proveedor: (r['proveedor'] ?? '').toString(),
        boleta: (r['boleta'] ?? '').toString(),
        lineas: _lineas(r['detalle']),
      );

  static List<LineaCompra> _lineas(Object? crudo) {
    if (crudo == null) return const [];
    try {
      final lista = jsonDecode(crudo.toString());
      if (lista is! List) return const [];
      return lista
          .whereType<Map<String, dynamic>>()
          .map(LineaCompra.fromJson)
          .toList();
    } catch (_) {
      // Una compra con el detalle ilegible no puede tumbar la lista entera.
      return const [];
    }
  }
}
