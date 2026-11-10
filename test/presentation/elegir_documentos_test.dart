import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/totales.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/calculadora_totales.dart';
import 'package:taller_repuestos/presentation/comunes/elegir_documentos.dart';

void main() {
  const taller = Trabajo(
    codigo: 'REP-1',
    tipo: TipoTrabajo.taller,
    estado: EstadoTrabajo.terminado,
    fecha: '2026-11-09',
    vistaDoc: VistaDoc.separado,
    trabajosRealizados: [LineaMano(desc: 'Lavado', precio: 40)],
    repuestos: [LineaRepuesto(desc: 'Foco', cantidad: 1, precio: 50)],
  );

  group('nombre del archivo', () {
    const dos = [0, 1];
    const una = [0];

    String nombre(bool reporte, List<int> notas, List<int> disponibles) =>
        SeleccionDocumentos(reporte: reporte, notas: notas)
            .nombreDeArchivo(taller, disponibles);

    test('con todo, solo el código', () {
      expect(nombre(true, dos, dos), 'REP-1.pdf');
    });

    test('dice qué lleva cuando no va todo', () {
      expect(nombre(true, const [], dos), 'REP-1 - Reporte de trabajo.pdf');
      expect(nombre(false, dos, dos), 'REP-1 - Notas de venta.pdf');
      expect(nombre(false, una, una), 'REP-1 - Nota de venta.pdf');
      expect(nombre(false, const [1], dos), 'REP-1 - Nota de venta 2 de 2.pdf');
      expect(
        nombre(true, const [0], dos),
        'REP-1 - Reporte y nota de venta 1 de 2.pdf',
      );
    });
  });

  test('una nota en cero no se ofrece', () {
    final sinRepuestos = calculadora.calcularBoletas(
      taller.copyWith(repuestos: const []),
    );
    expect(notasDisponibles(sinRepuestos), [0]);
    expect(notasDisponibles(calculadora.calcularBoletas(taller)), [0, 1]);
  });

  Future<SeleccionDocumentos?> abrir(
    WidgetTester tester,
    Trabajo t, {
    List<Boleta>? notas,
  }) async {
    SeleccionDocumentos? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            resultado = await elegirDocumentos(
              context,
              t,
              notas ?? calculadora.calcularBoletas(t),
              compartir: true,
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('una venta simple no pregunta', (tester) async {
    const venta = Trabajo(
      codigo: 'VTA-1',
      tipo: TipoTrabajo.venta,
      estado: EstadoTrabajo.terminado,
      fecha: '2026-11-09',
      repuestos: [LineaRepuesto(desc: 'Perno', cantidad: 1, precio: 5)],
    );

    final r = await abrir(tester, venta);

    expect(find.text('¿Qué quieres compartir?'), findsNothing);
    expect(r, isNotNull);
    expect(r!.reporte, isFalse);
    expect(r.notas, [0]);
  });

  testWidgets('desmarcar el reporte deja solo las notas', (tester) async {
    SeleccionDocumentos? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            resultado = await elegirDocumentos(
              context,
              taller,
              calculadora.calcularBoletas(taller),
              compartir: true,
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Reporte de trabajo'), findsOneWidget);
    expect(find.text('Nota de venta de mano de obra'), findsOneWidget);
    expect(find.text('Nota de venta de repuestos'), findsOneWidget);

    await tester.tap(find.text('Reporte de trabajo'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Compartir'));
    await tester.pumpAndSettle();

    expect(resultado!.reporte, isFalse);
    expect(resultado!.notas, [0, 1]);
  });

  testWidgets('sin nada marcado no se puede seguir', (tester) async {
    await abrir(tester, taller);

    await tester.tap(find.text('Reporte de trabajo'));
    await tester.tap(find.text('Nota de venta de mano de obra'));
    await tester.tap(find.text('Nota de venta de repuestos'));
    await tester.pump();

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });
}
