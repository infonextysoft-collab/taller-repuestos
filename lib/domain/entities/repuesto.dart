/// Un repuesto del inventario.
class Repuesto {
  const Repuesto({
    this.id,
    required this.nombre,
    this.stock = 0,
    this.precio = 0,
    this.codigoBarras,
  });

  final int? id;
  final String nombre;
  final int stock;
  final double precio;

  /// Un código vacío se guarda como **NULL**, nunca como cadena vacía: si no,
  /// el índice junta todos los repuestos sin código y la búsqueda por código
  /// devuelve cualquiera.
  final String? codigoBarras;

  bool get agotado => stock <= 0;

  Repuesto copyWith({
    int? id,
    String? nombre,
    int? stock,
    double? precio,
    String? codigoBarras,
    bool quitarCodigo = false,
  }) =>
      Repuesto(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        stock: stock ?? this.stock,
        precio: precio ?? this.precio,
        codigoBarras:
            quitarCodigo ? null : (codigoBarras ?? this.codigoBarras),
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'nombre': nombre.trim(),
        'stock': stock,
        'precio': precio,
        'codigoBarras': normalizarCodigo(codigoBarras),
      };

  factory Repuesto.fromRow(Map<String, Object?> r) => Repuesto(
        id: (r['id'] as num?)?.toInt(),
        nombre: (r['nombre'] ?? '').toString(),
        stock: (r['stock'] as num?)?.toInt() ?? 0,
        precio: (r['precio'] as num?)?.toDouble() ?? 0,
        codigoBarras: normalizarCodigo(r['codigoBarras']?.toString()),
      );
}

/// Un código vacío es `null`. Ver el comentario de [Repuesto.codigoBarras].
String? normalizarCodigo(String? codigo) {
  final c = (codigo ?? '').trim();
  return c.isEmpty ? null : c;
}
