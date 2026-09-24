import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:taller_repuestos/domain/entities/negocio.dart';
import 'package:taller_repuestos/domain/entities/totales.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/presentation/comunes/salida_pdf.dart';

void main() {
  late Directory carpeta;
  final bytes = Uint8List.fromList([37, 80, 68, 70]); // %PDF

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('descargas_');
  });

  tearDown(() async {
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
  });

  test('guarda con el nombre pedido', () async {
    final nombre = await escribirSinPisar(carpeta, bytes, 'REP-2026-0002.pdf');

    expect(nombre, 'REP-2026-0002.pdf');
    final archivo = File(p.join(carpeta.path, 'REP-2026-0002.pdf'));
    expect(await archivo.readAsBytes(), bytes);
  });

  test('no pisa lo que ya estaba: numera', () async {
    final previo = File(p.join(carpeta.path, 'REP-2026-0002.pdf'));
    await previo.writeAsString('lo que la persona ya tenía');

    final primero =
        await escribirSinPisar(carpeta, bytes, 'REP-2026-0002.pdf');
    final segundo =
        await escribirSinPisar(carpeta, bytes, 'REP-2026-0002.pdf');

    expect(primero, 'REP-2026-0002 (1).pdf');
    expect(segundo, 'REP-2026-0002 (2).pdf');
    expect(await previo.readAsString(), 'lo que la persona ya tenía');
  });

  test('sin carpeta devuelve null, para caer en el "Guardar como"', () async {
    final falta = Directory(p.join(carpeta.path, 'no-existe'));

    expect(await escribirSinPisar(falta, bytes, 'VTA-2026-0001.pdf'), isNull);
  });

  group('el mensaje con que se manda el documento', () {
    final trabajo = Trabajo(
      codigo: 'REP-2026-0002',
      tipo: TipoTrabajo.taller,
      totales: const Totales(total: 380),
    );

    test('lleva de qué documento se trata y cuánto es', () {
      final mensaje =
          mensajeDeEnvio(trabajo, const Negocio(nombre: 'Servicios MS'));

      expect(mensaje, 'Servicios MS · REP-2026-0002\nTotal: S/ 380.00');
    });

    test('con datos de cobro agrega a dónde pagar', () {
      final mensaje = mensajeDeEnvio(
        trabajo,
        const Negocio(
          nombre: 'Servicios MS',
          banco: 'BCP',
          cuenta: '191-0123456-0-12',
          yape: '999888777',
        ),
      );

      expect(mensaje, contains('Para el pago:'));
      expect(mensaje, contains('BCP: 191-0123456-0-12'));
      expect(mensaje, contains('Yape: 999888777'));
    });

    test('sin nombre de negocio no deja un separador colgando', () {
      final mensaje = mensajeDeEnvio(trabajo, const Negocio());

      expect(mensaje.split('\n').first, 'REP-2026-0002');
    });
  });
}
