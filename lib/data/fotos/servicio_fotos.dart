import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/foto.dart';

/// Las fotos del trabajo: cámara, galería y compresión.
///
/// Devuelve la foto ya comprimida, con su versión chica para las listas.
/// Se comprime siempre que se pueda: una foto de celular son 4 MB y en el
/// documento entra a 1400px de ancho sin que se note la diferencia.
///
/// Los bytes salen **crudos**, no en base64: ese formato infla el archivo un
/// 33% y es peso que después hay que subir y guardar sin ganar nada.
class ServicioFotos {
  ServicioFotos();

  static const int _anchoMaximo = 1400;
  static const int _calidad = 78;

  /// La copia para las listas: unos 8 KB contra los 300 de la completa.
  static const int _anchoMini = 200;
  static const int _calidadMini = 70;

  final ImagePicker _selector = ImagePicker();

  /// Saca una foto con la cámara. `null` si se canceló o no hay permiso.
  Future<Foto?> tomar() => _capturar(ImageSource.camera);

  /// Elige una de la galería o del disco.
  Future<Foto?> elegir() => _capturar(ImageSource.gallery);

  Future<Foto?> _capturar(ImageSource origen) async {
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
      return Foto(bytes: bytes, mini: await _miniatura(bytes));
    } catch (_) {
      // Sin cámara o sin permiso: el paso de fotos se puede saltar, así que no
      // vale la pena romper nada.
      return null;
    }
  }

  /// La versión chica. En el navegador no hay compresor nativo: se devuelve
  /// `null` y la lista cae a la foto completa.
  Future<Uint8List?> _miniatura(Uint8List bytes) async {
    if (kIsWeb) return null;

    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        quality: _calidadMini,
        minWidth: _anchoMini,
        minHeight: 1,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
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
