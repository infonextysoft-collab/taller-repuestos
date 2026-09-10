/// Datos del emisor que salen impresos en la cabecera de los documentos.
/// Siempre es un solo registro (id = 1).
class Negocio {
  const Negocio({
    this.nombre = '',
    this.ruc = '',
    this.direccion = '',
    this.telefono = '',
    this.email = '',
  });

  final String nombre;
  final String ruc;
  final String direccion;
  final String telefono;
  final String email;

  bool get estaVacio => nombre.trim().isEmpty && ruc.trim().isEmpty;

  Negocio copyWith({
    String? nombre,
    String? ruc,
    String? direccion,
    String? telefono,
    String? email,
  }) =>
      Negocio(
        nombre: nombre ?? this.nombre,
        ruc: ruc ?? this.ruc,
        direccion: direccion ?? this.direccion,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
      );

  Map<String, Object?> toRow() => {
        'id': 1,
        'nombre': nombre,
        'ruc': ruc,
        'direccion': direccion,
        'telefono': telefono,
        'email': email,
      };

  factory Negocio.fromRow(Map<String, Object?> r) => Negocio(
        nombre: (r['nombre'] ?? '').toString(),
        ruc: (r['ruc'] ?? '').toString(),
        direccion: (r['direccion'] ?? '').toString(),
        telefono: (r['telefono'] ?? '').toString(),
        email: (r['email'] ?? '').toString(),
      );
}
