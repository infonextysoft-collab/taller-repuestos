import 'dart:convert';
import 'dart:typed_data';

/// Las fotos se guardan como **datos**, no como ruta de archivo.
///
/// Una ruta solo existe en el dispositivo que la escribió: no se puede leer
/// desde el navegador, se rompe si el sistema limpia la carpeta temporal, y
/// obliga a que el generador del PDF sepa de archivos. Guardando los bytes en
/// el propio registro, la foto viaja con el trabajo y se dibuja igual en todos
/// lados.
///
/// El formato es una data URI (`data:image/jpeg;base64,...`), que además se
/// puede pegar tal cual en cualquier visor si hiciera falta depurar.
const String _prefijoJpeg = 'data:image/jpeg;base64,';

/// Empaqueta bytes de imagen en el formato que guarda la base.
String fotoDesdeBytes(Uint8List bytes) => '$_prefijoJpeg${base64Encode(bytes)}';

/// Devuelve los bytes de una foto guardada, o `null` si el dato está roto.
///
/// Nunca lanza: una foto ilegible no puede tumbar una lista ni un documento.
Uint8List? bytesDeFoto(String? foto) {
  if (foto == null || foto.isEmpty) return null;

  try {
    final coma = foto.indexOf(',');
    final datos = foto.startsWith('data:') && coma >= 0
        ? foto.substring(coma + 1)
        : foto;
    return base64Decode(datos);
  } catch (_) {
    return null;
  }
}
