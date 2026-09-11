import 'dart:typed_data';

/// En qué momento del trabajo se sacó la foto.
enum MomentoFoto { ingreso, entrega }

/// Una foto de un trabajo.
///
/// Vive en su **propia tabla**, no adentro del registro, y por tres razones
/// concretas:
///
///   1. **Los bytes van crudos.** Antes se guardaban convertidas a texto
///      (base64), un formato que infla cualquier archivo un 33% sin mejorar
///      nada. Guardar el JPEG tal cual devuelve ese tercio.
///   2. **El historial deja de arrastrarlas.** Listar cincuenta registros
///      cargaba las fotos de los cincuenta. Ahora la lista pide solo [mini].
///   3. **Cada foto se sube una sola vez.** [remota] guarda dónde quedó en la
///      nube; mientras sea `null`, está pendiente de subir. Sin esto, un
///      respaldo diario reenviaría las mismas fotos todos los días.
class Foto {
  const Foto({
    this.id,
    required this.bytes,
    this.mini,
    this.remota,
  });

  /// `null` mientras no se guardó todavía.
  final int? id;

  /// El JPEG completo, el que va al documento.
  final Uint8List bytes;

  /// Una versión chica para las listas. Puede faltar —en el navegador no hay
  /// compresor nativo—, y entonces se cae a [bytes].
  final Uint8List? mini;

  /// Dónde quedó en la nube. `null` = todavía no se subió.
  final String? remota;

  bool get subida => remota != null;

  /// Lo que se muestra en una lista: la chica si existe, si no la completa.
  Uint8List get paraLista => mini ?? bytes;

  Foto copyWith({int? id, Uint8List? mini, String? remota}) => Foto(
        id: id ?? this.id,
        bytes: bytes,
        mini: mini ?? this.mini,
        remota: remota ?? this.remota,
      );

  Map<String, Object?> toRow(int trabajoId, MomentoFoto momento, int orden) => {
        if (id != null) 'id': id,
        'trabajoId': trabajoId,
        'momento': momento.name,
        'orden': orden,
        'bytes': bytes,
        'mini': mini,
        'remota': remota,
      };

  factory Foto.fromRow(Map<String, Object?> r) => Foto(
        id: (r['id'] as num?)?.toInt(),
        bytes: r['bytes'] as Uint8List? ?? Uint8List(0),
        mini: r['mini'] as Uint8List?,
        remota: r['remota']?.toString(),
      );
}
