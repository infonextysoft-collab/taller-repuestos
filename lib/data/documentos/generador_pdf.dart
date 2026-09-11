import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/dinero.dart';
import '../../core/utils/fechas.dart';
import '../../core/utils/letras.dart';
import '../../domain/entities/linea.dart';
import '../../domain/entities/negocio.dart';
import '../../domain/entities/totales.dart';
import '../../domain/entities/foto.dart';
import '../../domain/entities/trabajo.dart';
import '../../domain/services/calculadora_totales.dart';

/// Los PDF: Reporte de servicio y Boleta(s).
///
/// Se **dibuja** el documento, no se captura la pantalla: el papel es papel,
/// no una foto de la app. Así el texto queda seleccionable, pesa poco y no
/// depende de cómo se vea la interfaz en cada celular.
class GeneradorPdf {
  GeneradorPdf();

  static const PdfColor _vino = PdfColor.fromInt(0xFF761C1C);
  static const PdfColor _texto = PdfColor.fromInt(0xFF1B1A18);
  static const PdfColor _gris = PdfColor.fromInt(0xFF6B6862);
  static const PdfColor _linea = PdfColor.fromInt(0xFFD6D2CB);

  static const double _mm = PdfPageFormat.mm;

  /// El logo se lee una sola vez. Si no carga, el documento sale **sin logo**
  /// en vez de no salir.
  static Uint8List? _logo;
  static bool _logoIntentado = false;

  static Future<Uint8List?> _cargarLogo() async {
    if (_logoIntentado) return _logo;
    _logoIntentado = true;
    try {
      final datos = await rootBundle.load('assets/img/logo.png');
      _logo = datos.buffer.asUint8List();
    } catch (_) {
      _logo = null;
    }
    return _logo;
  }

  /// El documento completo: el Reporte y la(s) Boleta(s) juntos, sin importar
  /// en qué pestaña esté parado el usuario.
  Future<Uint8List> completo(Trabajo t, Negocio negocio) =>
      _armar(t, negocio, conReporte: t.tipo.llevaReporte, boletas: null);

  Future<Uint8List> soloReporte(Trabajo t, Negocio negocio) =>
      _armar(t, negocio, conReporte: true, boletas: const []);

  /// Una sola boleta — el botón de descarga individual del modo separado.
  Future<Uint8List> soloBoleta(Trabajo t, Negocio negocio, int indice) =>
      _armar(t, negocio, conReporte: false, boletas: [indice]);

  Future<Uint8List> _armar(
    Trabajo t,
    Negocio negocio, {
    required bool conReporte,
    required List<int>? boletas,
  }) async {
    final logo = await _cargarLogo();
    final doc = pw.Document(compress: true);
    final todas = calculadora.calcularBoletas(t);
    final indices = boletas ?? List.generate(todas.length, (i) => i);

    final fotosIngreso = _imagenes(t.fotosIngreso);
    final fotosEntrega = _imagenes(t.fotosEntrega);

    final tema = pw.PageTheme(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 16 * _mm,
        marginRight: 16 * _mm,
        marginTop: 16 * _mm,
        marginBottom: 16 * _mm,
      ),
    );

    if (conReporte) {
      doc.addPage(pw.MultiPage(
        pageTheme: tema,
        build: (ctx) => _reporte(t, negocio, logo, fotosIngreso, fotosEntrega),
      ));
    }

    for (final i in indices) {
      if (i < 0 || i >= todas.length) continue;
      doc.addPage(pw.MultiPage(
        pageTheme: tema,
        build: (ctx) => _boleta(t, negocio, todas[i], logo),
      ));
    }

    return doc.save();
  }

  /// Las fotos vienen guardadas como datos en el propio registro, así que el
  /// documento no depende de que exista un archivo en el disco.
  List<pw.MemoryImage> _imagenes(List<Foto> fotos) {
    final imagenes = <pw.MemoryImage>[];

    for (final foto in fotos) {
      // Una foto ilegible no puede tumbar el documento entero.
      if (foto.bytes.isEmpty) continue;
      try {
        imagenes.add(pw.MemoryImage(foto.bytes));
      } catch (_) {
        continue;
      }
    }

    return imagenes;
  }

  /* ------------------------------------------------------------ cabecera */

  /// Tres zonas: logo, quién emite, y qué documento es.
  ///
  /// La caja de la derecha separa "quién emite" de "qué documento es". El
  /// código no va enorme a la izquierda: el cliente busca primero de quién es
  /// el papel.
  pw.Widget _cabecera(Negocio n, String clase, String codigo, Uint8List? logo) {
    final contacto = <String>[
      if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
      [n.telefono.trim(), n.email.trim()].where((s) => s.isNotEmpty).join('   '),
    ].where((s) => s.isNotEmpty).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.SizedBox(
                width: 20 * _mm,
                height: 20 * _mm,
                child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 4 * _mm),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    n.nombre.trim().isEmpty ? 'Taller' : n.nombre.trim(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                  pw.SizedBox(height: 2 * _mm),
                  for (final l in contacto)
                    pw.Text(l,
                        style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
                ],
              ),
            ),
            pw.SizedBox(width: 4 * _mm),
            pw.Container(
              width: 62 * _mm,
              height: 26 * _mm,
              padding: pw.EdgeInsets.all(2 * _mm),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _texto, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2 * _mm),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    n.ruc.trim().isEmpty ? 'R.U.C. —' : 'R.U.C. ${n.ruc.trim()}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                  pw.Text(
                    clase.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9.5, color: _vino),
                  ),
                  pw.Text(
                    'N° $codigo',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Container(height: 0.6, color: _texto),
        pw.SizedBox(height: 6 * _mm),
      ],
    );
  }

  /* -------------------------------------------------------------- piezas */

  pw.Widget _subtitulo(String texto) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 2 * _mm),
        child: pw.Text(
          texto.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _gris,
          ),
        ),
      );

  /// Dos filas —etiquetas arriba, valores abajo—, no una fila por campo. Es el
  /// formato de las órdenes de servicio de taller y se lee de un golpe.
  pw.Widget? _tablaDatos(String titulo, List<List<String>> columnas) {
    final visibles =
        columnas.where((c) => c.length > 1 && c[1].trim().isNotEmpty).toList();
    if (visibles.isEmpty) return null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _subtitulo(titulo),
        pw.Table(
          border: pw.TableBorder.all(color: _linea, width: 0.2),
          children: [
            pw.TableRow(
              children: [
                for (final c in visibles)
                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(2 * _mm, 1.4 * _mm, 2 * _mm, 0),
                    child: pw.Text(
                      c[0].toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _gris,
                      ),
                    ),
                  ),
              ],
            ),
            pw.TableRow(
              children: [
                for (final c in visibles)
                  pw.Padding(
                    padding:
                        pw.EdgeInsets.fromLTRB(2 * _mm, 0.8 * _mm, 2 * _mm, 1.6 * _mm),
                    child: pw.Text(
                      c[1],
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 9, color: _texto),
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4 * _mm),
      ],
    );
  }

  pw.Widget _parrafo(String texto) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 4 * _mm),
        child: pw.Text(texto.trim(),
            style: const pw.TextStyle(fontSize: 10, color: _texto)),
      );

  /// Tabla de líneas. La cantidad **solo aparece cuando significa algo**: la
  /// mano de obra se cobra por el trabajo, no por unidades, y una columna de
  /// unos es ruido en un comprobante.
  pw.Widget _tablaLineas(
    List<LineaDocumento> items, {
    required bool conCantidad,
  }) {
    pw.Widget celda(String t,
            {bool cabecera = false,
            bool derecha = false,
            bool negrita = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 1.4 * _mm),
          child: pw.Text(
            t,
            textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: cabecera ? 7.5 : 9.5,
              color: cabecera ? _gris : _texto,
              fontWeight: (cabecera || negrita)
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        );

    final anchos = conCantidad
        ? <int, pw.TableColumnWidth>{
            0: const pw.FlexColumnWidth(5),
            1: const pw.FlexColumnWidth(1.1),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.8),
          }
        : <int, pw.TableColumnWidth>{
            0: const pw.FlexColumnWidth(7),
            1: const pw.FlexColumnWidth(2),
          };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          columnWidths: anchos,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _linea, width: 0.2)),
              ),
              children: conCantidad
                  ? [
                      celda('DESCRIPCION', cabecera: true),
                      celda('CANT.', cabecera: true, derecha: true),
                      celda('P. UNIT.', cabecera: true, derecha: true),
                      celda('IMPORTE', cabecera: true, derecha: true),
                    ]
                  : [
                      celda('DESCRIPCION', cabecera: true),
                      celda('IMPORTE', cabecera: true, derecha: true),
                    ],
            ),
            for (final item in items)
              pw.TableRow(
                children: conCantidad
                    ? [
                        celda(item.desc),
                        celda('${item.cant}', derecha: true),
                        celda(soles(item.precio), derecha: true),
                        celda(soles(item.importe), derecha: true, negrita: true),
                      ]
                    : [
                        celda(item.desc),
                        celda(soles(item.importe), derecha: true, negrita: true),
                      ],
              ),
          ],
        ),
        pw.SizedBox(height: 4 * _mm),
      ],
    );
  }

  /// Fotos en dos columnas. Solo las que existen — nunca recuadros vacíos.
  pw.Widget _fotos(List<pw.MemoryImage> imagenes) {
    final filas = <pw.Widget>[];

    for (var i = 0; i < imagenes.length; i += 2) {
      filas.add(pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 3 * _mm),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.AspectRatio(
                aspectRatio: 4 / 3,
                child: pw.Image(imagenes[i], fit: pw.BoxFit.cover),
              ),
            ),
            pw.SizedBox(width: 3 * _mm),
            pw.Expanded(
              child: i + 1 < imagenes.length
                  ? pw.AspectRatio(
                      aspectRatio: 4 / 3,
                      child: pw.Image(imagenes[i + 1], fit: pw.BoxFit.cover),
                    )
                  : pw.SizedBox(),
            ),
          ],
        ),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: filas,
    );
  }

  /// Alineado a la derecha. El desagregado del IGV va **debajo** del total y
  /// en chico, porque el impuesto ya está adentro y no se le suma. Ponerlo
  /// antes, como en una factura común, contaría la historia al revés.
  pw.Widget _bloqueTotales(Boleta b) {
    pw.Widget fila(String etiqueta, double valor,
            {double tam = 9.5, PdfColor color = _gris}) =>
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 1.2 * _mm),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(etiqueta,
                  style: pw.TextStyle(fontSize: tam, color: color)),
              pw.Text(soles(valor),
                  style: pw.TextStyle(
                      fontSize: tam,
                      color: tam >= 9.5 ? _texto : color)),
            ],
          ),
        );

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 72 * _mm,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            fila('Subtotal', b.subtotal),
            if (b.descuento > 0) fila('Descuento', -b.descuento),
            pw.SizedBox(height: 1 * _mm),
            pw.Container(height: 0.2, color: _linea),
            pw.SizedBox(height: 2.5 * _mm),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    )),
                pw.Text(soles(b.total),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _vino,
                    )),
              ],
            ),
            pw.SizedBox(height: 2.5 * _mm),
            fila('Op. gravada', b.gravado, tam: 8.5),
            fila('IGV (18%) incluido', b.igv, tam: 8.5),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------- documentos */

  List<pw.Widget> _reporte(
    Trabajo t,
    Negocio negocio,
    Uint8List? logo,
    List<pw.MemoryImage> fotosIngreso,
    List<pw.MemoryImage> fotosEntrega,
  ) {
    final bloques = <pw.Widget>[
      _cabecera(negocio, 'Reporte de servicio', t.codigo, logo),
    ];

    void agregar(pw.Widget? w) {
      if (w != null) bloques.add(w);
    }

    agregar(_tablaDatos('Datos del cliente', [
      ['Cliente', t.cliente],
      ['RUC / DNI', t.ruc],
      ['Fecha', formatoCorto(t.fecha)],
      ['Servicio', t.tipo.nombreServicio],
    ]));

    agregar(_tablaDatos('Datos del equipo', [
      ['Equipo', t.equipo],
      ['Modelo / N° serie', t.modelo],
      ['Ubicación', t.ubicacion],
    ]));

    if (t.observaciones.trim().isNotEmpty) {
      bloques.add(_subtitulo('Observaciones'));
      bloques.add(_parrafo(t.observaciones));
    }

    if (t.diagnostico.trim().isNotEmpty) {
      bloques.add(_subtitulo('Diagnóstico'));
      bloques.add(_parrafo(t.diagnostico));
    }

    if (fotosIngreso.isNotEmpty) {
      bloques.add(_subtitulo('Fotos de ingreso'));
      bloques.add(_fotos(fotosIngreso));
    }

    if (t.trabajosRealizados.isNotEmpty) {
      bloques.add(_subtitulo('Trabajos realizados'));
      bloques.add(_tablaLineas(t.trabajosRealizados, conCantidad: false));
    }

    if (t.repuestos.isNotEmpty) {
      bloques.add(_subtitulo('Repuestos utilizados'));
      bloques.add(_tablaLineas(t.repuestos, conCantidad: true));
    }

    if (fotosEntrega.isNotEmpty) {
      bloques.add(_subtitulo('Fotos finales'));
      bloques.add(_fotos(fotosEntrega));
    }

    if (t.recomendaciones.trim().isNotEmpty) {
      bloques.add(_subtitulo('Recomendaciones'));
      bloques.add(_parrafo(t.recomendaciones));
    }

    return bloques;
  }

  List<pw.Widget> _boleta(
    Trabajo t,
    Negocio negocio,
    Boleta boleta,
    Uint8List? logo,
  ) {
    final totales = calculadora.calcular(t);

    final bloques = <pw.Widget>[
      _cabecera(negocio, boleta.titulo, t.codigo, logo),
    ];

    void agregar(pw.Widget? w) {
      if (w != null) bloques.add(w);
    }

    agregar(_tablaDatos('Datos del cliente', [
      ['Facturar a', t.aQuienFacturar],
      ['RUC / DNI', t.ruc],
      ['Fecha', formatoCorto(t.fecha)],
    ]));

    agregar(_tablaDatos('Equipo', [
      ['Equipo', t.equipo],
      ['Modelo / N° serie', t.modelo],
    ]));

    if (boleta.incluyeManoDeObra && t.trabajosRealizados.isNotEmpty) {
      bloques.add(_subtitulo('Mano de obra'));
      bloques.add(_tablaLineas(t.trabajosRealizados, conCantidad: false));
    }

    if (boleta.incluyeRepuestos && t.repuestos.isNotEmpty) {
      bloques.add(_subtitulo('Repuestos'));
      bloques.add(_tablaLineas(t.repuestos, conCantidad: true));
    }

    // El traslado va con la mano de obra.
    if (boleta.incluyeManoDeObra && totales.subTraslado > 0) {
      bloques.add(_subtitulo('Traslado'));
      bloques.add(_tablaLineas(
        [
          LineaRepuesto(
            desc: 'Movilidad propia, ${t.vueltas} vuelta(s)',
            cantidad: t.vueltas,
            precio: t.precioVuelta,
          ),
        ],
        conCantidad: true,
      ));
    }

    bloques.add(pw.SizedBox(height: 2 * _mm));
    bloques.add(_bloqueTotales(boleta));
    bloques.add(pw.SizedBox(height: 4 * _mm));

    // El monto en letras: formalidad de todo comprobante peruano, y de paso
    // deja el importe escrito de dos formas distintas.
    bloques.add(pw.Text(
      montoEnLetras(boleta.total),
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: _gris,
      ),
    ));

    return bloques;
  }
}
