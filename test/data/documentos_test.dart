import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/documentos/generador_pdf.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/calculadora_totales.dart';

/// El PDF no se puede leer con los ojos desde un test —sale comprimido—, así
/// que acá se comprueba que **se arma**: que el pie de pago, los descuentos
/// por línea y las dos secciones de la tabla no lo rompen.
///
/// Para mirarlo de verdad, se puede volcar una muestra:
///
/// ```
/// MUESTRA_PDF=/ruta/muestra.pdf flutter test test/data/documentos_test.dart
/// ```
///
/// `MUESTRA_REPORTE` hace lo mismo con el reporte de servicio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final trabajo = Trabajo(
    id: 1,
    codigo: 'REP-2026-0002',
    tipo: TipoTrabajo.taller,
    estado: EstadoTrabajo.terminado,
    fecha: '2026-09-13',
    cliente: 'Juan Ramírez',
    ruc: '12345678',
    equipo: 'MG',
    modelo: 'MG 5',
    placa: 'T7D164',
    anio: '2023',
    nMotor: '15S4C9KGN6280408',
    vin: 'LSJA36E31PZ042103',
    diagnostico: 'Cables rotos',
    trabajosRealizados: const [
      LineaMano(desc: 'Diagnóstico vehicular', precio: 80),
      LineaMano(desc: 'Lavado básico', precio: 40),
      LineaMano(desc: 'Cambio de focos de luz baja y alta LH - RH', precio: 30),
      LineaMano(desc: 'Cambio de refrigerante de motor', precio: 30, dto: 10),
    ],
    repuestos: const [
      LineaRepuesto(desc: 'Foco HB3', cantidad: 2, precio: 50, costo: 32),
      LineaRepuesto(desc: 'Refrigerante rojo 50/50 LT', cantidad: 1, precio: 40),
      LineaRepuesto(
        desc: 'Espárrago más tuerca',
        cantidad: 1,
        precio: 30,
        dto: 20,
      ),
    ],
  );

  const conPago = Negocio(
    nombre: 'Servicios MS',
    ruc: '20131312955',
    direccion: 'Av. Industrial 455, Lima',
    telefono: '999888777',
    banco: 'BCP',
    cuenta: '191-0123456-0-12',
    cci: '00219100123456012',
    yape: '999888777',
  );

  // El mismo negocio sin los datos de cobro: así lo único que cambia entre un
  // documento y el otro es el pie de pago, y no la cabecera.
  final sinPago = conPago.copyWith(banco: '', cuenta: '', cci: '', yape: '');

  Future<void> esUnPdf(List<int> bytes) async {
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  }

  test('la boleta se arma con los datos de pago al pie', () async {
    final bytes = await GeneradorPdf().soloBoleta(trabajo, conPago, 0);
    await esUnPdf(bytes);

    final destino = Platform.environment['MUESTRA_PDF'];
    if (destino != null) await File(destino).writeAsBytes(bytes);
  });

  test('sin datos de cobro la boleta sale igual, sin el pie', () async {
    final pelada = await GeneradorPdf().soloBoleta(trabajo, sinPago, 0);
    await esUnPdf(pelada);

    final conDatos = await GeneradorPdf().soloBoleta(trabajo, conPago, 0);
    expect(pelada.length, lessThan(conDatos.length),
        reason: 'el pie de pago tiene que ocupar lugar en el documento');
  });

  test('el reporte de servicio no lleva datos de pago', () async {
    final conDatos = await GeneradorPdf().soloReporte(trabajo, conPago);
    final sinDatos = await GeneradorPdf().soloReporte(trabajo, sinPago);

    await esUnPdf(conDatos);
    // Mismo documento: el pie de pago es cosa de la boleta, la que se paga.
    expect(conDatos.length, sinDatos.length);

    final destino = Platform.environment['MUESTRA_REPORTE'];
    if (destino != null) await File(destino).writeAsBytes(conDatos);
  });

  test('las dos boletas separadas se arman con una sección cada una', () async {
    final separado = trabajo.copyWith(vistaDoc: VistaDoc.separado);

    await esUnPdf(await GeneradorPdf().soloBoleta(separado, conPago, 0));
    await esUnPdf(await GeneradorPdf().soloBoleta(separado, conPago, 1));
  });

  test('una venta sin mano de obra arma la boleta igual', () async {
    const venta = Trabajo(
      codigo: 'VTA-2026-0004',
      tipo: TipoTrabajo.venta,
      estado: EstadoTrabajo.terminado,
      fecha: '2026-09-20',
      cliente: 'Mostrador',
      repuestos: [
        LineaRepuesto(desc: 'Perno', cantidad: 10, precio: 5),
      ],
    );

    await esUnPdf(await GeneradorPdf().soloBoleta(venta, conPago, 0));
  });

  // La tabla de la boleta va en tramos sueltos para poder centrar los rótulos
  // de sección. Si alguna vez se meten en una sola columna, una boleta que no
  // entra en una hoja deja de armarse: esto es lo que lo cuida.
  test('una boleta larga sigue en otra hoja en vez de romperse', () async {
    final larga = trabajo.copyWith(
      trabajosRealizados: [
        for (var i = 1; i <= 30; i++) LineaMano(desc: 'Trabajo $i', precio: 10),
      ],
      repuestos: [
        for (var i = 1; i <= 30; i++)
          LineaRepuesto(desc: 'Repuesto $i', cantidad: 1, precio: 5),
      ],
    );

    final bytes = await GeneradorPdf().soloBoleta(larga, conPago, 0);
    await esUnPdf(bytes);

    final hojas = RegExp(r'/Type\s*/Page[^s]').allMatches(
      String.fromCharCodes(bytes),
    );
    expect(hojas.length, greaterThan(1), reason: '60 renglones no entran en una');
  });

  int hojasDe(List<int> bytes) => RegExp(r'/Type\s*/Page[^s]')
      .allMatches(String.fromCharCodes(bytes))
      .length;

  // Cada cantidad deja el corte de hoja en otro lugar. Es lo que puede colgar
  // o romper el armado: un bloque que no entra y no se puede partir.
  test('la nota de venta se arma con cualquier cantidad de renglones', () async {
    for (var n = 0; n <= 70; n++) {
      final variable = trabajo.copyWith(
        trabajosRealizados: [
          for (var i = 1; i <= n ~/ 2; i++)
            LineaMano(desc: 'Trabajo $i', precio: 10),
        ],
        repuestos: [
          for (var i = 1; i <= n - n ~/ 2; i++)
            LineaRepuesto(desc: 'Repuesto $i', cantidad: 1, precio: 5),
        ],
      );

      await esUnPdf(await GeneradorPdf().soloBoleta(variable, conPago, 0));
    }
  });

  test('el reporte de trabajo se arma con cualquier cantidad de renglones',
      () async {
    final largo = 'Revisión completa del sistema eléctrico y de carga. ' * 90;

    for (var n = 0; n <= 70; n += 3) {
      final variable = trabajo.copyWith(
        observaciones: largo,
        recomendaciones: largo,
        trabajosRealizados: [
          for (var i = 1; i <= n; i++)
            LineaMano(desc: 'Trabajo $i', precio: 10),
        ],
        repuestos: [
          for (var i = 1; i <= n; i++)
            LineaRepuesto(desc: 'Repuesto $i', cantidad: 1, precio: 5),
        ],
      );

      await esUnPdf(await GeneradorPdf().soloReporte(variable, conPago));
    }
  });

  test('un renglón larguísimo no cuelga el armado', () async {
    final enorme = trabajo.copyWith(
      trabajosRealizados: [
        LineaMano(desc: 'Trabajo muy detallado ' * 400, precio: 10),
        const LineaMano(desc: 'Otro', precio: 10),
      ],
      repuestos: const [],
    );

    await esUnPdf(await GeneradorPdf().soloBoleta(enorme, conPago, 0));
  });

  test('seleccion arma solo lo que se marcó', () async {
    final separado = trabajo.copyWith(vistaDoc: VistaDoc.separado);
    final pdf = GeneradorPdf();

    final soloNotas = await pdf.seleccion(
      separado,
      conPago,
      conReporte: false,
      notas: const [0, 1],
    );
    final soloUna = await pdf.seleccion(
      separado,
      conPago,
      conReporte: false,
      notas: const [1],
    );
    final todo = await pdf.seleccion(
      separado,
      conPago,
      conReporte: true,
      notas: const [0, 1],
    );

    expect(hojasDe(soloNotas), 2);
    expect(hojasDe(soloUna), 1);
    expect(hojasDe(todo), 3);

    final destino = Platform.environment['MUESTRA_SEPARADO'];
    if (destino != null) await File(destino).writeAsBytes(todo);
  });

  test('una venta simple no agrega reporte aunque se pida', () async {
    const venta = Trabajo(
      codigo: 'VTA-2026-0005',
      tipo: TipoTrabajo.venta,
      estado: EstadoTrabajo.terminado,
      fecha: '2026-09-20',
      cliente: 'Mostrador',
      repuestos: [LineaRepuesto(desc: 'Perno', cantidad: 10, precio: 5)],
    );

    final bytes = await GeneradorPdf().seleccion(
      venta,
      conPago,
      conReporte: true,
      notas: const [0],
    );
    expect(hojasDe(bytes), 1);
  });

  test('muestras largas para mirar los cortes de hoja', () async {
    final prefijo = Platform.environment['MUESTRA_LARGA'];
    if (prefijo == null) return;

    for (final n in [17, 20, 22, 26, 34, 45]) {
      final variable = trabajo.copyWith(
        trabajosRealizados: [
          for (var i = 1; i <= n ~/ 2; i++)
            LineaMano(desc: 'Trabajo número $i', precio: 10),
        ],
        repuestos: [
          for (var i = 1; i <= n - n ~/ 2; i++)
            LineaRepuesto(desc: 'Repuesto número $i', cantidad: 1, precio: 5),
        ],
      );

      await File('$prefijo-nota-$n.pdf')
          .writeAsBytes(await GeneradorPdf().soloBoleta(variable, conPago, 0));
      await File('$prefijo-reporte-$n.pdf')
          .writeAsBytes(await GeneradorPdf().soloReporte(variable, conPago));
    }
  });

  test('los subtotales de la boleta son los mismos que calcula la app', () {
    final tot = calculadora.calcular(trabajo);

    // 80 + 40 + 30 + 27 (el último con 10 % de rebaja).
    expect(tot.subTrabajos, 177);
    // 100 + 40 + 24 (el último con 20 %).
    expect(tot.subRepuestos, 164);
    expect(tot.total, 341);
  });
}
