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

/// Los PDF: Reporte de trabajo y Nota(s) de venta.
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

  /// El encabezado de la tabla de la boleta y la fila que abre cada sección.
  static const PdfColor _cabeceraTabla = PdfColor.fromInt(0xFFEDEAE4);
  static const PdfColor _seccionTabla = PdfColor.fromInt(0xFFF6F4F0);

  static const double _mm = PdfPageFormat.mm;

  /// Lo que mide de ancho el contenido de una hoja, ya sin los márgenes.
  static double get _anchoUtil => PdfPageFormat.a4.width - 32 * _mm;

  /// Un bloque "que no se separa" tiene que entrar en una hoja: si fuera más
  /// alto no entraría en ninguna, y la librería seguiría abriendo hojas sin
  /// parar. Por encima de esta medida se deja cortar.
  static const double _altoMaximoBloque = 200 * _mm;

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

  /// Lo que se marcó en la ventana de compartir, en un solo PDF.
  Future<Uint8List> seleccion(
    Trabajo t,
    Negocio negocio, {
    required bool conReporte,
    required List<int> notas,
  }) => _armar(
    t,
    negocio,
    conReporte: conReporte && t.tipo.llevaReporte,
    boletas: notas,
  );

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
      doc.addPage(
        pw.MultiPage(
          pageTheme: tema,
          build: (ctx) =>
              _reporte(ctx, t, negocio, logo, fotosIngreso, fotosEntrega),
        ),
      );
    }

    // El "1 de 2" cuenta solo las notas que dicen algo: en el modo separado,
    // un trabajo sin repuestos tiene una sola nota de verdad.
    final conAlgo = [
      for (var k = 0; k < todas.length; k++)
        if (todas[k].subtotal > 0) k,
    ];

    for (final i in indices) {
      if (i < 0 || i >= todas.length) continue;

      final numero = conAlgo.indexOf(i) + 1;

      // En la primera hoja el encabezado de la tabla va debajo de su título.
      // De la segunda en adelante se repite arriba: una hoja que empieza con
      // números sueltos no dice qué columna es cada uno.
      int? primeraHoja;

      doc.addPage(
        pw.MultiPage(
          pageTheme: tema,
          header: (ctx) {
            primeraHoja ??= ctx.pageNumber;
            return ctx.pageNumber == primeraHoja
                ? pw.SizedBox()
                : _encabezadoTablaBoleta();
          },
          footer: (ctx) => _pieDePago(negocio),
          build: (ctx) => _boleta(
            ctx,
            t,
            negocio,
            todas[i],
            logo,
            parte: conAlgo.length > 1 && numero > 0
                ? '$numero de ${conAlgo.length}'
                : null,
          ),
        ),
      );
    }

    return doc.save();
  }

  /* --------------------------------------------------- medir y no cortar */

  /// Lo que va a medir de alto un pedazo de documento, antes de ponerlo.
  double _alto(pw.Context ctx, pw.Widget w) {
    w.layout(
      ctx,
      pw.BoxConstraints(maxWidth: _anchoUtil),
      parentUsesSize: false,
    );
    return w.box!.height;
  }

  /// Salta de hoja si no queda lugar para [muestra], que es lo mínimo que
  /// tiene que quedar junto: el título con el comienzo de lo que titula.
  ///
  /// Así un título nunca queda solo al final de una hoja.
  pw.Widget _saltoSiNoEntra(pw.Context ctx, pw.Widget muestra) {
    final alto = _alto(ctx, muestra);
    return pw.NewPage(
      freeSpace: alto < _altoMaximoBloque ? alto : _altoMaximoBloque,
    );
  }

  /// Varias piezas que van juntas: si no entran en lo que queda de la hoja,
  /// pasan todas a la siguiente.
  ///
  /// Si juntas son más altas que una hoja, se devuelven sueltas: mejor un
  /// título separado de su tabla que un documento que no se arma.
  List<pw.Widget> _juntos(pw.Context ctx, List<pw.Widget> piezas) {
    final bloque = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: piezas,
    );
    return _alto(ctx, bloque) < _altoMaximoBloque
        ? [pw.Inseparable(child: bloque)]
        : piezas;
  }

  /// Una descripción, con un tope muy por encima de lo que se escribe a mano.
  ///
  /// Un renglón no se parte entre hojas, así que uno más alto que la hoja no
  /// entra en ninguna y el documento no terminaría de armarse nunca.
  static String _renglon(String texto) =>
      texto.length <= 1500 ? texto : '${texto.substring(0, 1500)}...';

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
  ///
  /// [parte] es el "1 de 2" de las notas separadas: dice que falta otro papel.
  pw.Widget _cabecera(
    Negocio n,
    String clase,
    String codigo,
    Uint8List? logo, {
    String? parte,
  }) {
    final contacto = <String>[
      if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
      [
        n.telefono.trim(),
        n.email.trim(),
      ].where((s) => s.isNotEmpty).join('   '),
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
                    pw.Text(
                      l,
                      style: const pw.TextStyle(fontSize: 8.5, color: _gris),
                    ),
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
                    n.ruc.trim().isEmpty
                        ? 'R.U.C. —'
                        : 'R.U.C. ${n.ruc.trim()}',
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
                  if (parte != null)
                    pw.Text(
                      parte.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 8,
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

  /// El rótulo de un bloque. En la boleta y en el reporte va **centrado**: los
  /// bloques son tablas y párrafos del ancho de la hoja, y un rótulo al centro
  /// se distingue de un renglón más, que siempre empieza a la izquierda.
  ///
  /// Debajo lleva una raya negra de lado a lado, que corta la hoja en bloques:
  /// se ve dónde termina uno y empieza el siguiente sin leer los rótulos.
  ///
  /// El rótulo va en negro, igual que la raya: en gris se perdía al lado de
  /// ella, y en papel impreso o en una foto por WhatsApp el gris claro es lo
  /// primero que desaparece.
  pw.Widget _subtitulo(String texto, {bool centrado = false}) {
    final rotulo = pw.Text(
      texto.toUpperCase(),
      textAlign: centrado ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: _texto,
      ),
    );

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 2.5 * _mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Centrar pide el ancho entero: suelto, el texto mide lo que mide y
          // no tiene respecto de qué centrarse.
          centrado ? pw.Center(child: rotulo) : rotulo,
          pw.SizedBox(height: 1.2 * _mm),
          pw.Container(height: 0.9, color: _texto),
        ],
      ),
    );
  }

  /// Dos filas —etiquetas arriba, valores abajo—, no una fila por campo. Es el
  /// formato de las órdenes de servicio de taller y se lee de un golpe.
  pw.Widget? _tablaDatos(
    String titulo,
    List<List<String>> columnas, {
    bool mayus = false,
    bool centrado = false,
  }) {
    final visibles = columnas
        .where((c) => c.length > 1 && c[1].trim().isNotEmpty)
        .toList();
    if (visibles.isEmpty) return null;

    // Inseparable: el rótulo no se puede quedar solo al final de una hoja, ni
    // las etiquetas en una y los valores en la otra.
    return pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Con el título vacío no se dibuja encabezado: así un mismo bloque
          // puede partirse en dos filas sin repetir el rótulo.
          if (titulo.trim().isNotEmpty) _subtitulo(titulo, centrado: centrado),
          pw.Table(
            border: pw.TableBorder.all(color: _linea, width: 0.2),
            children: [
              pw.TableRow(
                children: [
                  for (final c in visibles)
                    pw.Padding(
                      padding: pw.EdgeInsets.fromLTRB(
                        2 * _mm,
                        1.4 * _mm,
                        2 * _mm,
                        0,
                      ),
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
                      padding: pw.EdgeInsets.fromLTRB(
                        2 * _mm,
                        0.8 * _mm,
                        2 * _mm,
                        1.6 * _mm,
                      ),
                      child: pw.Text(
                        mayus ? c[1].toUpperCase() : c[1],
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
      ),
    );
  }

  static const pw.TextStyle _estiloParrafo = pw.TextStyle(
    fontSize: 10,
    color: _texto,
  );

  /// `span`: un texto largo sigue en la hoja siguiente en vez de romper el
  /// documento.
  pw.Widget _parrafo(String texto) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 4 * _mm),
    child: pw.Text(
      texto.trim(),
      overflow: pw.TextOverflow.span,
      style: _estiloParrafo,
    ),
  );

  /// Tabla de líneas. La cantidad **solo aparece cuando significa algo**: la
  /// mano de obra se cobra por el trabajo, no por unidades, y una columna de
  /// unos es ruido en un comprobante.
  ///
  /// Si no entra en una hoja, los renglones siguen en la otra —enteros— y el
  /// encabezado se repite arriba. Por eso va suelta y no dentro de una
  /// columna: la tabla sola sabe partirse entre renglones.
  pw.Widget _tablaLineas(
    List<LineaDocumento> items, {
    required bool conCantidad,
  }) {
    pw.Widget celda(
      String t, {
      bool cabecera = false,
      bool derecha = false,
      bool negrita = false,
    }) => pw.Padding(
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

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4 * _mm),
      child: pw.Table(
        columnWidths: anchos,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _linea, width: 0.2),
              ),
            ),
            children: conCantidad
                ? [
                    celda('DESCRIPCIÓN', cabecera: true),
                    celda('CANT.', cabecera: true, derecha: true),
                    celda('P. UNIT.', cabecera: true, derecha: true),
                    celda('IMPORTE', cabecera: true, derecha: true),
                  ]
                : [
                    celda('DESCRIPCIÓN', cabecera: true),
                    celda('IMPORTE', cabecera: true, derecha: true),
                  ],
          ),
          for (final item in items)
            pw.TableRow(
              children: conCantidad
                  ? [
                      celda(_renglon(item.desc)),
                      celda('${item.cant}', derecha: true),
                      celda(soles(item.precio), derecha: true),
                      celda(soles(item.importe), derecha: true, negrita: true),
                    ]
                  : [
                      celda(_renglon(item.desc)),
                      celda(soles(item.importe), derecha: true, negrita: true),
                    ],
            ),
        ],
      ),
    );
  }

  /// Fotos en dos columnas. Solo las que existen — nunca recuadros vacíos.
  ///
  /// Una foto no se parte, y el título se queda con la primera fila.
  List<pw.Widget> _fotos(
    pw.Context ctx,
    String titulo,
    List<pw.MemoryImage> imagenes,
  ) {
    final filas = <pw.Widget>[];

    for (var i = 0; i < imagenes.length; i += 2) {
      filas.add(
        pw.Padding(
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
        ),
      );
    }

    return [
      ..._juntos(ctx, [_subtitulo(titulo, centrado: true), filas.first]),
      ...filas.skip(1),
    ];
  }

  /* ---------------------------------------------------------- documentos */

  List<pw.Widget> _reporte(
    pw.Context ctx,
    Trabajo t,
    Negocio negocio,
    Uint8List? logo,
    List<pw.MemoryImage> fotosIngreso,
    List<pw.MemoryImage> fotosEntrega,
  ) {
    final bloques = <pw.Widget>[
      _cabecera(negocio, 'Reporte de trabajo', t.codigo, logo),
    ];

    void agregar(pw.Widget? w) {
      if (w != null) bloques.add(w);
    }

    // Un texto: el título se queda con sus tres primeras líneas.
    void texto(String titulo, String contenido) {
      if (contenido.trim().isEmpty) return;

      bloques.add(
        _saltoSiNoEntra(
          ctx,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _subtitulo(titulo, centrado: true),
              pw.Text(contenido.trim(), maxLines: 3, style: _estiloParrafo),
            ],
          ),
        ),
      );
      bloques.add(_subtitulo(titulo, centrado: true));
      bloques.add(_parrafo(contenido));
    }

    // Una tabla: el título, su encabezado y los dos primeros renglones.
    void tabla(
      String titulo,
      List<LineaDocumento> items, {
      required bool conCantidad,
    }) {
      if (items.isEmpty) return;

      bloques.add(
        _saltoSiNoEntra(
          ctx,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _subtitulo(titulo, centrado: true),
              _tablaLineas(items.take(2).toList(), conCantidad: conCantidad),
            ],
          ),
        ),
      );
      bloques.add(_subtitulo(titulo, centrado: true));
      bloques.add(_tablaLineas(items, conCantidad: conCantidad));
    }

    agregar(
      _tablaDatos('Datos del cliente', [
        ['Cliente', t.cliente],
        ['RUC / DNI', t.ruc],
        ['Fecha', formatoCorto(t.fecha)],
        ['Servicio', t.tipo.nombreServicio],
      ], centrado: true),
    );

    agregar(
      _tablaDatos('Datos del equipo', [
        ['Equipo', t.equipo],
        ['Modelo / N° serie', t.modelo],
        ['Año', t.anio],
      ], centrado: true),
    );

    // Segunda fila del mismo bloque: tres datos largos no entran en la de
    // arriba sin quedar cortados, y los que no se cargaron no salen.
    agregar(
      _tablaDatos('', [
        ['Placa', t.placa],
        ['N° de motor', t.nMotor],
        ['VIN', t.vin],
      ]),
    );

    agregar(
      _tablaDatos('', [
        ['Ubicación', t.ubicacion],
      ]),
    );

    texto('Observaciones', t.observaciones);
    texto('Diagnóstico', t.diagnostico);

    if (fotosIngreso.isNotEmpty) {
      bloques.addAll(_fotos(ctx, 'Fotos de ingreso', fotosIngreso));
    }

    tabla('Trabajos realizados', t.trabajosRealizados, conCantidad: false);
    tabla('Repuestos utilizados', t.repuestos, conCantidad: true);

    if (fotosEntrega.isNotEmpty) {
      bloques.addAll(_fotos(ctx, 'Fotos finales', fotosEntrega));
    }

    texto('Recomendaciones', t.recomendaciones);

    return bloques;
  }

  /* ------------------------------------------------- tabla de la boleta */

  /// La mano de obra de la boleta, con el traslado adentro.
  ///
  /// El traslado es mano de obra: es tu tiempo y tu camioneta, no una pieza.
  /// Antes salía en una tabla aparte al final, lejos de lo que cobra.
  static List<LineaDocumento> _conTraslado(Trabajo t, Totales tot) => [
    ...t.trabajosRealizados,
    if (tot.subTraslado > 0)
      LineaRepuesto(
        desc: 'Movilidad propia, ${t.vueltas} vuelta(s)',
        cantidad: t.vueltas,
        precio: t.precioVuelta,
      ),
  ];

  /// Los anchos de la tabla de la boleta. Todos los tramos usan estos mismos:
  /// es lo que hace que se lean como una sola tabla.
  static const Map<int, pw.TableColumnWidth> _anchosBoleta = {
    0: pw.FlexColumnWidth(5),
    1: pw.FlexColumnWidth(1.3),
    2: pw.FlexColumnWidth(1.5),
    3: pw.FlexColumnWidth(1.2),
    4: pw.FlexColumnWidth(1.8),
  };

  static const pw.BorderSide _bordeBoleta = pw.BorderSide(
    color: _linea,
    width: 0.4,
  );

  /// Un tramo de la tabla. Solo el primero lleva borde arriba: los demás se
  /// apoyan en el de abajo del tramo anterior, y si cada uno trajera el suyo
  /// la línea saldría doble justo en la unión.
  pw.TableBorder _bordeTramo({required bool techo}) => pw.TableBorder(
    top: techo ? _bordeBoleta : pw.BorderSide.none,
    left: _bordeBoleta,
    right: _bordeBoleta,
    bottom: _bordeBoleta,
    horizontalInside: _bordeBoleta,
    verticalInside: _bordeBoleta,
  );

  pw.Widget _celdaBoleta(
    String texto, {
    bool cabecera = false,
    pw.TextAlign alinear = pw.TextAlign.left,
    bool negrita = false,
  }) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(
      horizontal: 1.6 * _mm,
      vertical: 1.3 * _mm,
    ),
    child: pw.Text(
      texto,
      textAlign: alinear,
      style: pw.TextStyle(
        fontSize: cabecera ? 7.5 : 8.8,
        color: _texto,
        fontWeight: (cabecera || negrita)
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
      ),
    ),
  );

  /// Va debajo del título en la primera hoja y arriba de todo en las demás.
  pw.Widget _encabezadoTablaBoleta() => pw.Table(
    border: _bordeTramo(techo: true),
    columnWidths: _anchosBoleta,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _cabeceraTabla),
        children: [
          for (final columna in const [
            'DESCRIPCIÓN',
            'CANTIDAD',
            'PRECIO',
            '% DTO.',
            'TOTAL',
          ])
            _celdaBoleta(columna, cabecera: true, alinear: pw.TextAlign.center),
        ],
      ),
    ],
  );

  /// El rótulo de una sección: centrado en el ancho entero, y no en la columna
  /// de la descripción, para que no se confunda con un renglón.
  pw.Widget _franjaSeccion(String rotulo) => pw.Container(
    padding: pw.EdgeInsets.symmetric(
      horizontal: 1.6 * _mm,
      vertical: 1.3 * _mm,
    ),
    decoration: const pw.BoxDecoration(
      color: _seccionTabla,
      border: pw.Border(
        left: _bordeBoleta,
        right: _bordeBoleta,
        bottom: _bordeBoleta,
      ),
    ),
    child: pw.Center(
      child: pw.Text(
        rotulo.toUpperCase(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8.8,
          fontWeight: pw.FontWeight.bold,
          color: _texto,
        ),
      ),
    ),
  );

  pw.Widget _filasBoleta(List<LineaDocumento> lineas) => pw.Table(
    border: _bordeTramo(techo: false),
    columnWidths: _anchosBoleta,
    children: [
      for (final l in lineas)
        pw.TableRow(
          children: [
            _celdaBoleta(_renglon(l.desc).toUpperCase()),
            _celdaBoleta(
              l.cant.toStringAsFixed(2),
              alinear: pw.TextAlign.right,
            ),
            _celdaBoleta(
              soles(l.precio, simbolo: false),
              alinear: pw.TextAlign.right,
            ),
            _celdaBoleta(
              l.dtoValido.toStringAsFixed(2),
              alinear: pw.TextAlign.right,
            ),
            _celdaBoleta(
              soles(l.importe, simbolo: false),
              alinear: pw.TextAlign.right,
              negrita: true,
            ),
          ],
        ),
    ],
  );

  /// La tabla de la nota de venta: **una sola a la vista**, con la mano de
  /// obra y los repuestos como secciones adentro, y su cierre debajo.
  ///
  /// Por dentro son tramos, porque una tabla de PDF no une celdas y el rótulo
  /// de la sección va en el ancho entero. Los tramos se arman para que al
  /// cambiar de hoja **nada quede huérfano**:
  ///
  ///   * el título, el encabezado y los dos primeros renglones van juntos;
  ///   * cada sección arranca con su franja y dos renglones;
  ///   * el total va con los dos últimos renglones: un total solo en una hoja
  ///     no se entiende de qué es.
  ///
  /// Los renglones del medio van sueltos, que es lo que les deja seguir en la
  /// hoja siguiente sin cortarse.
  List<pw.Widget> _cuerpoBoleta(
    pw.Context ctx,
    pw.Widget subtitulo,
    List<(String, List<LineaDocumento>)> secciones,
    List<pw.Widget> cierre,
  ) {
    final visibles = secciones.where((s) => s.$2.isNotEmpty).toList();

    // El rótulo de la sección solo se dibuja si hay más de una: con una sola,
    // repetir "Repuestos" arriba y adentro es decirlo dos veces.
    final conRotulos = visibles.length > 1;

    final salida = <pw.Widget>[];
    var bloque = <pw.Widget>[subtitulo, _encabezadoTablaBoleta()];

    for (var i = 0; i < visibles.length; i++) {
      final (rotulo, lineas) = visibles[i];
      if (conRotulos) bloque.add(_franjaSeccion(rotulo));

      final inicio = lineas.take(2).toList();
      final resto = lineas.skip(2).toList();

      if (i < visibles.length - 1) {
        bloque.add(_filasBoleta(inicio));
        salida.addAll(_juntos(ctx, bloque));
        if (resto.isNotEmpty) salida.add(_filasBoleta(resto));
        bloque = <pw.Widget>[];
        continue;
      }

      final corte = resto.length > 2 ? resto.length - 2 : 0;
      final medio = resto.sublist(0, corte);
      final finales = resto.sublist(corte);

      if (medio.isEmpty) {
        // Pocos renglones: todo cabe en un solo bloque.
        bloque.add(_filasBoleta([...inicio, ...finales]));
        salida.addAll(_juntos(ctx, [...bloque, ...cierre]));
      } else {
        bloque.add(_filasBoleta(inicio));
        salida.addAll(_juntos(ctx, bloque));
        salida.add(_filasBoleta(medio));
        salida.addAll(_juntos(ctx, [_filasBoleta(finales), ...cierre]));
      }
      return salida;
    }

    // Una nota sin renglones: igual sale con su encabezado y su total.
    salida.addAll(_juntos(ctx, [...bloque, ...cierre]));
    return salida;
  }

  /// Los totales, pegados debajo de la tabla y con el borde alineado con su
  /// última columna: es la misma tabla, partida.
  pw.Widget _totalesBoleta(List<(String, double)> filas, double total) {
    pw.TableRow armar(String etiqueta, double valor, {bool fuerte = false}) {
      pw.Widget celda(String texto, {required bool derecha, PdfColor? color}) =>
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(
              horizontal: 1.6 * _mm,
              vertical: 1.3 * _mm,
            ),
            child: pw.Text(
              texto,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: fuerte ? 10 : 8.8,
                fontWeight: pw.FontWeight.bold,
                color: color ?? _texto,
              ),
            ),
          );

      return pw.TableRow(
        children: [
          celda(etiqueta, derecha: true),
          celda(
            soles(valor, simbolo: false),
            derecha: true,
            color: fuerte ? _vino : _texto,
          ),
        ],
      );
    }

    return pw.Table(
      // Sin borde arriba: se apoya en el último tramo de la tabla de líneas.
      border: _bordeTramo(techo: false),
      columnWidths: const {
        0: pw.FlexColumnWidth(9.0),
        1: pw.FlexColumnWidth(1.8),
      },
      children: [
        for (final f in filas) armar(f.$1, f.$2),
        armar('TOTAL:', total, fuerte: true),
      ],
    );
  }

  /// Con qué pagar: al pie, a la izquierda y dentro de un recuadro.
  ///
  /// Va impreso en el papel a propósito —y no solo en el mensaje con que se
  /// manda— porque WhatsApp descarta el texto cuando lo que se adjunta es un
  /// PDF, y así los datos viajan igual.
  pw.Widget _bloquePago(Negocio n) => pw.Container(
    padding: pw.EdgeInsets.all(2.6 * _mm),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _vino, width: 0.8),
      borderRadius: pw.BorderRadius.circular(1.5 * _mm),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          'FORMAS DE PAGO',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _vino,
          ),
        ),
        pw.SizedBox(height: 1.8 * _mm),
        for (final dato in n.datosPago)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 1 * _mm),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '${dato.etiqueta.toUpperCase()}: ',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                  pw.TextSpan(
                    text: dato.valor.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 8.5, color: _texto),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  /// Una línea del desagregado del IGV. Va en chico y **debajo** del total,
  /// porque el impuesto ya está adentro y no se le suma. Ponerlo antes, como
  /// en una factura común, contaría la historia al revés.
  pw.Widget _desglose(String etiqueta, double valor) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 1.2 * _mm),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: _gris)),
        pw.Text(
          soles(valor),
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      ],
    ),
  );

  /* ---------------------------------------------------------- la boleta */

  List<pw.Widget> _boleta(
    pw.Context ctx,
    Trabajo t,
    Negocio negocio,
    Boleta boleta,
    Uint8List? logo, {
    String? parte,
  }) {
    final tot = calculadora.calcular(t);

    final mano = boleta.incluyeManoDeObra
        ? _conTraslado(t, tot)
        : const <LineaDocumento>[];
    final repuestos = boleta.incluyeRepuestos
        ? t.repuestos
        : const <LineaRepuesto>[];

    final bloques = <pw.Widget>[
      _cabecera(negocio, boleta.titulo, t.codigo, logo, parte: parte),
    ];

    void agregar(pw.Widget? w) {
      if (w != null) bloques.add(w);
    }

    // De los datos del cliente para abajo va todo en mayúsculas: es como se
    // leen las notas de taller, y de paso un nombre cargado a las apuradas
    // sale parejo con el resto.
    agregar(
      _tablaDatos(
        'Datos del cliente',
        [
          ['Cliente', t.aQuienFacturar],
          ['RUC / DNI', t.ruc],
          ['Fecha', formatoCorto(t.fecha)],
        ],
        mayus: true,
        centrado: true,
      ),
    );

    agregar(
      _tablaDatos(
        'Datos del vehículo',
        [
          ['Equipo', t.equipo],
          ['Modelo / N° serie', t.modelo],
          ['Año', t.anio],
        ],
        mayus: true,
        centrado: true,
      ),
    );

    agregar(
      _tablaDatos('', [
        ['Placa', t.placa],
        ['N° de motor', t.nMotor],
        ['VIN', t.vin],
      ], mayus: true),
    );

    final subtitulo = _subtitulo(
      mano.isNotEmpty && repuestos.isNotEmpty
          ? 'Mano de obra / Repuestos'
          : repuestos.isNotEmpty
          ? 'Repuestos'
          : 'Mano de obra',
      centrado: true,
    );

    final cierre = <pw.Widget>[
      _totalesBoleta([
        if (mano.isNotEmpty && repuestos.isNotEmpty) ...[
          ('TOTAL MANO DE OBRA:', calculadora.sumarLineas(mano)),
          ('TOTAL REPUESTOS:', calculadora.sumarLineas(repuestos)),
        ],
        if (boleta.descuento > 0) ('DESCUENTO:', -boleta.descuento),
      ], boleta.total),
      pw.SizedBox(height: 3 * _mm),
      // El monto en letras: formalidad de todo comprobante peruano, y de paso
      // deja el importe escrito de dos formas distintas.
      pw.Text(
        montoEnLetras(boleta.total).toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _texto,
        ),
      ),
      pw.SizedBox(height: 4 * _mm),
      // El desagregado del impuesto se queda pegado a los totales, debajo de
      // donde quedó el número: es parte de la cuenta. Con qué pagar no —eso
      // baja al pie de la hoja, ver [_pieDePago].
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 72 * _mm,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _desglose('OP. GRAVADA', boleta.gravado),
              _desglose('IGV (18%) INCLUIDO', boleta.igv),
            ],
          ),
        ),
      ),
    ];

    bloques.addAll(
      _cuerpoBoleta(ctx, subtitulo, [
        ('Mano de obra', mano),
        ('Repuestos', repuestos),
      ], cierre),
    );

    return bloques;
  }

  /// Con qué pagar, **al pie de la hoja y a la izquierda**, que es donde se
  /// lo busca en cualquier boleta.
  ///
  /// Va como pie de página y no como último bloque del contenido: si fuera
  /// contenido quedaría pegado a los totales, a media hoja, y en una boleta
  /// corta —dos líneas— eso no es "el pie", es el medio. Como pie baja
  /// siempre hasta abajo, tenga la boleta tres renglones o treinta.
  pw.Widget _pieDePago(Negocio n) {
    if (n.datosPago.isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: pw.EdgeInsets.only(top: 6 * _mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(flex: 6, child: _bloquePago(n)),
          // La mitad derecha queda vacía a propósito: es el aire que hace que
          // el recuadro se lea como algo puesto a un costado.
          pw.Expanded(flex: 5, child: pw.SizedBox()),
        ],
      ),
    );
  }
}
