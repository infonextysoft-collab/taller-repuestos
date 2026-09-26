import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/documentos/generador_pdf.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';

/// El PDF no se puede leer con los ojos desde un test —sale comprimido—, así
/// que acá se comprueba que **se arma**: que agregarle el pie de pago no lo
/// rompe ni con datos ni sin ellos.
///
/// Para mirarlo de verdad, se puede volcar una muestra:
///
/// ```
/// MUESTRA_PDF=/ruta/muestra.pdf flutter test test/data/documentos_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final trabajo = Trabajo(
    id: 1,
    codigo: 'REP-2026-0002',
    tipo: TipoTrabajo.taller,
    estado: EstadoTrabajo.terminado,
    fecha: '2026-09-13',
    cliente: 'Juan Ramírez',
    equipo: 'MG',
    modelo: 'MG 5',
    placa: 'T7D164',
    anio: '2023',
    nMotor: '15S4C9KGN6280408',
    vin: 'LSJA36E31PZ042103',
    diagnostico: 'Cables rotos',
    trabajosRealizados: const [
      LineaMano(desc: 'Rebobinado del motor', precio: 300),
    ],
    repuestos: const [
      LineaRepuesto(desc: 'Filtro de aceite', cantidad: 2, precio: 38.5),
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
  });
}
