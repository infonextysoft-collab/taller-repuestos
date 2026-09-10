import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/imagenes.dart';

/// Las fotos del trabajo: cámara, galería y compresión.
///
/// Devuelve la foto ya comprimida y lista para guardar (ver [fotoDesdeBytes]).
/// Se comprime siempre que se pueda: una foto de celular son 4 MB y en el
/// documento entra a 1400px de ancho sin que se note la diferencia.
class ServicioFotos {
  ServicioFotos();

  static const int _anchoMaximo = 1400;
  static const int _calidad = 78;

  final ImagePicker _selector = ImagePicker();

  /// Saca una foto con la cámara. `null` si se canceló o no hay permiso.
  Future<String?> tomar() => _capturar(ImageSource.camera);

  /// Elige una de la galería o del disco.
  Future<String?> elegir() => _capturar(ImageSource.gallery);

  Future<String?> _capturar(ImageSource origen) async {
    try {
      final tomada = await _selector.pickImage(
        source: origen,
        // En el navegador esto ya redimensiona al elegir; en el celular es un
        // primer recorte antes de la compresión de verdad.
        maxWidth: _anchoMaximo.toDouble(),
        imageQuality: 90,
      );
      if (tomada == null) return null;

      final bytes = await _comprimir(await tomada.readAsBytes());
      return fotoDesdeBytes(bytes);
    } catch (_) {
      // Sin cámara o sin permiso: el paso de fotos se puede saltar, así que no
      // vale la pena romper nada.
      return null;
    }
  }

  Future<Uint8List> _comprimir(Uint8List original) async {
    // El compresor nativo no existe en web. Ahí alcanza con lo que ya hizo el
    // selector al redimensionar.
    if (kIsWeb) return original;

    try {
      return await FlutterImageCompress.compressWithList(
        original,
        quality: _calidad,
        minWidth: _anchoMaximo,
        minHeight: 1,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Mejor una foto pesada que ninguna.
      return original;
    }
  }
}
