/// Datos del emisor que salen impresos en la cabecera de los documentos.
/// Siempre es un solo registro (id = 1).
class Negocio {
  const Negocio({
    this.nombre = '',
    this.ruc = '',
    this.direccion = '',
    this.telefono = '',
    this.email = '',
    this.banco = '',
    this.cuenta = '',
    this.cci = '',
    this.yape = '',
  });

  final String nombre;
  final String ruc;
  final String direccion;
  final String telefono;
  final String email;

  /// Con qué te pagan.
  ///
  /// Van al **pie de la boleta**, no a la cabecera: son lo que el cliente
  /// necesita después de ver cuánto debe, no antes. Y no van al Reporte de
  /// servicio, que es el papel de qué se hizo, no el que se paga.
  final String banco;
  final String cuenta;

  /// El interbancario. Sin él no te pueden transferir desde otro banco.
  final String cci;
  final String yape;

  bool get estaVacio => nombre.trim().isEmpty && ruc.trim().isEmpty;

  /// Los datos de cobro cargados, rotulados y listos para imprimir.
  ///
  /// Una cuenta sin banco igual sirve —se rotula "Cuenta" a secas—, pero un
  /// banco sin número no dice nada, así que ese no sale solo.
  List<({String etiqueta, String valor})> get datosPago => [
        if (cuenta.trim().isNotEmpty)
          (
            etiqueta: banco.trim().isEmpty ? 'Cuenta' : banco.trim(),
            valor: cuenta.trim(),
          ),
        if (cci.trim().isNotEmpty) (etiqueta: 'CCI', valor: cci.trim()),
        if (yape.trim().isNotEmpty) (etiqueta: 'Yape', valor: yape.trim()),
      ];

  Negocio copyWith({
    String? nombre,
    String? ruc,
    String? direccion,
    String? telefono,
    String? email,
    String? banco,
    String? cuenta,
    String? cci,
    String? yape,
  }) =>
      Negocio(
        nombre: nombre ?? this.nombre,
        ruc: ruc ?? this.ruc,
        direccion: direccion ?? this.direccion,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        banco: banco ?? this.banco,
        cuenta: cuenta ?? this.cuenta,
        cci: cci ?? this.cci,
        yape: yape ?? this.yape,
      );

  Map<String, Object?> toRow() => {
        'id': 1,
        'nombre': nombre,
        'ruc': ruc,
        'direccion': direccion,
        'telefono': telefono,
        'email': email,
        'banco': banco,
        'cuenta': cuenta,
        'cci': cci,
        'yape': yape,
      };

  factory Negocio.fromRow(Map<String, Object?> r) => Negocio(
        nombre: (r['nombre'] ?? '').toString(),
        ruc: (r['ruc'] ?? '').toString(),
        direccion: (r['direccion'] ?? '').toString(),
        telefono: (r['telefono'] ?? '').toString(),
        email: (r['email'] ?? '').toString(),
        banco: (r['banco'] ?? '').toString(),
        cuenta: (r['cuenta'] ?? '').toString(),
        cci: (r['cci'] ?? '').toString(),
        yape: (r['yape'] ?? '').toString(),
      );
}
