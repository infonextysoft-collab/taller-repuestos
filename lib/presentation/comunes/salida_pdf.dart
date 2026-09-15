import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../core/widgets/avisos.dart';

/// La carpeta pública de descargas del teléfono: la misma que abre la app
/// "Archivos" en "Descargas".
///
/// Va escrita a mano porque `path_provider` solo da la carpeta privada de la
/// app, que la persona no encuentra nunca.
const _descargas = '/storage/emulated/0/Download';

/// Guarda el PDF en el teléfono y avisa dónde quedó.
///
/// Descargar tiene que **descargar**, no abrir la hoja de compartir: para
/// mandarlo está el botón de al lado. En Android 11 o más nuevo se escribe
/// directo en Descargas, sin preguntar nada. Si el teléfono no deja —Android
/// viejo, un segundo usuario—, se abre el "Guardar como" del sistema, que
/// funciona en todos.
Future<void> descargarPdf(
  BuildContext context,
  Uint8List bytes,
  String nombre,
) async {
  if (!kIsWeb && Platform.isAndroid) {
    final guardado = await escribirSinPisar(Directory(_descargas), bytes, nombre);
    if (guardado != null) {
      if (context.mounted) {
        mostrarAviso(context, 'Guardado en Descargas: $guardado');
      }
      return;
    }
  }

  final destino = await FilePicker.saveFile(
    fileName: nombre,
    bytes: bytes,
    mimeType: 'application/pdf',
  );
  // En el navegador el archivo se baja solo y ya se ve abajo; en el teléfono,
  // cancelar el "Guardar como" no merece un aviso.
  if (destino != null && !kIsWeb && context.mounted) {
    mostrarAviso(context, 'PDF guardado.');
  }
}

/// La hoja de compartir del sistema: WhatsApp, correo, Drive.
Future<void> compartirPdf(Uint8List bytes, String nombre) =>
    Printing.sharePdf(bytes: bytes, filename: nombre);

/// Escribe [bytes] en [carpeta] con [nombre], o con `nombre (1)`, `(2)`…
/// si ya hay uno: **nunca pisa** un archivo que la persona ya tenía.
///
/// Devuelve el nombre con que quedó, o `null` si no se pudo escribir. Tres
/// intentos fallidos alcanzan para saber que la carpeta no deja: seguir
/// probando nombres no lo va a arreglar.
@visibleForTesting
Future<String?> escribirSinPisar(
  Directory carpeta,
  Uint8List bytes,
  String nombre,
) async {
  final base = p.basenameWithoutExtension(nombre);
  final extension = p.extension(nombre);
  var fallos = 0;

  try {
    if (!await carpeta.exists()) return null;

    for (var i = 0; i < 100 && fallos < 3; i++) {
      final candidato = i == 0 ? nombre : '$base ($i)$extension';
      final archivo = File(p.join(carpeta.path, candidato));
      if (await archivo.exists()) continue;

      try {
        await archivo.writeAsBytes(bytes, flush: true);
        return candidato;
      } on FileSystemException {
        fallos++;
        // Un archivo a medio escribir en Descargas es peor que ninguno.
        try {
          if (await archivo.exists()) await archivo.delete();
        } on FileSystemException {
          // Si tampoco deja borrarlo, no hay nada más que hacer.
        }
      }
    }
  } on FileSystemException {
    return null;
  }
  return null;
}
