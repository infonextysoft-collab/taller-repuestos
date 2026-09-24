import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/dinero.dart';
import '../../core/widgets/avisos.dart';
import '../../domain/entities/negocio.dart';
import '../../domain/entities/trabajo.dart';

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
///
/// El [mensaje] viaja de dos maneras a propósito: como texto del envío **y al
/// portapapeles**. No es redundancia — **WhatsApp descarta el texto cuando lo
/// adjuntado es un PDF** (con fotos lo respeta como descripción, con
/// documentos no), así que la única forma de que llegue al chat es pegarlo.
/// Por eso los datos de pago también van impresos en la boleta: ese camino no
/// depende de por dónde se mande.
Future<void> compartirPdf(
  Uint8List bytes,
  String nombre, {
  String mensaje = '',
}) async {
  final texto = mensaje.trim();
  if (texto.isNotEmpty) {
    await Clipboard.setData(ClipboardData(text: texto));
  }

  // En el navegador no hay disco donde dejarlo; en el teléfono se escribe un
  // temporal para que el archivo llegue con su nombre y no con uno inventado.
  final archivo = kIsWeb
      ? XFile.fromData(bytes, mimeType: 'application/pdf')
      : XFile(await _temporal(bytes, nombre), mimeType: 'application/pdf');

  await SharePlus.instance.share(ShareParams(
    files: [archivo],
    fileNameOverrides: kIsWeb ? [nombre] : null,
    text: texto.isEmpty ? null : texto,
  ));
}

Future<String> _temporal(Uint8List bytes, String nombre) async {
  final carpeta = await getTemporaryDirectory();
  final archivo = File(p.join(carpeta.path, nombre));
  await archivo.writeAsBytes(bytes, flush: true);
  return archivo.path;
}

/// El mensaje que acompaña al documento: qué es, cuánto y a dónde pagar.
///
/// Sin datos de cobro cargados quedan las dos primeras líneas, que igual
/// sirven de referencia en el chat.
String mensajeDeEnvio(Trabajo t, Negocio n) {
  final encabezado =
      [n.nombre.trim(), t.codigo].where((s) => s.isNotEmpty).join(' · ');

  final lineas = <String>[
    if (encabezado.isNotEmpty) encabezado,
    'Total: ${soles(t.totales.total)}',
  ];

  final pago = n.datosPago;
  if (pago.isNotEmpty) {
    lineas.add('');
    lineas.add('Para el pago:');
    for (final dato in pago) {
      lineas.add('${dato.etiqueta}: ${dato.valor}');
    }
  }

  return lineas.join('\n');
}

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
