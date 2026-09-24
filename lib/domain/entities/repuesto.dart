import '../../core/utils/dinero.dart';

/// Un repuesto del inventario.
class Repuesto {
  const Repuesto({
    this.id,
    required this.nombre,
    this.stock = 0,
    this.precio = 0,
    this.precioCosto = 0,
    this.codigoBarras,
  });

  final int? id;
  final String nombre;
  final int stock;

  /// A cuánto se vende.
  final double precio;

  /// A cuánto se compra. **Cero significa "no se sabe"**, no "es gratis": es
  /// lo que traen todos los repuestos cargados antes de que existiera este
  /// campo, y por eso la ganancia se calla en vez de inventar un número.
  final double precioCosto;

  /// Un código vacío se guarda como **NULL**, nunca como cadena vacía: si no,
  /// el índice junta todos los repuestos sin código y la búsqueda por código
  /// devuelve cualquiera.
  final String? codigoBarras;

  bool get agotado => stock <= 0;

  /// Lo que deja cada unidad, o `null` si falta el precio de compra.
  double? get utilidad =>
      precioCosto <= 0 ? null : redondear(precio - precioCosto);

  /// Esa misma ganancia como porcentaje de lo que se cobra.
  double? get margen {
    final gana = utilidad;
    if (gana == null || precio <= 0) return null;
    return gana / precio * 100;
  }

  Repuesto copyWith({
    int? id,
    String? nombre,
    int? stock,
    double? precio,
    double? precioCosto,
    String? codigoBarras,
    bool quitarCodigo = false,
  }) =>
      Repuesto(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        stock: stock ?? this.stock,
        precio: precio ?? this.precio,
        precioCosto: precioCosto ?? this.precioCosto,
        codigoBarras:
            quitarCodigo ? null : (codigoBarras ?? this.codigoBarras),
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'nombre': nombre.trim(),
        'stock': stock,
        'precio': precio,
        'precioCosto': precioCosto,
        'codigoBarras': normalizarCodigo(codigoBarras),
      };

  factory Repuesto.fromRow(Map<String, Object?> r) => Repuesto(
        id: (r['id'] as num?)?.toInt(),
        nombre: (r['nombre'] ?? '').toString(),
        stock: (r['stock'] as num?)?.toInt() ?? 0,
        precio: (r['precio'] as num?)?.toDouble() ?? 0,
        precioCosto: (r['precioCosto'] as num?)?.toDouble() ?? 0,
        codigoBarras: normalizarCodigo(r['codigoBarras']?.toString()),
      );
}

/// Un código vacío es `null`. Ver el comentario de [Repuesto.codigoBarras].
String? normalizarCodigo(String? codigo) {
  final c = (codigo ?? '').trim();
  return c.isEmpty ? null : c;
}
