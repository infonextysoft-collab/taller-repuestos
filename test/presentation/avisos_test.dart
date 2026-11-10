import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/app/providers.dart';
import 'package:taller_repuestos/core/theme/app_theme.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/entities/repeticion.dart';
import 'package:taller_repuestos/domain/repositories/recordatorios_repository.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/acciones_aviso.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/formulario_recordatorio.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/pantalla_completados.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/pantalla_recordatorios.dart';

class _RepoFalso implements RecordatoriosRepository {
  _RepoFalso([this.items = const []]);

  List<Recordatorio> items;
  final llamadas = <String>[];
  Recordatorio? actualizado;

  @override
  Future<List<Recordatorio>> listar({
    bool incluirCumplidos = true,
    bool incluirEliminados = false,
  }) async =>
      items.where((r) => incluirEliminados || !r.eliminado).toList();

  @override
  Future<int> refrescarVencidos() async => 0;

  @override
  Future<int> contarVencidos() async => 0;

  @override
  Future<void> eliminar(int id) async => llamadas.add('eliminar');

  @override
  Future<int?> eliminarYSeguir(int id) async {
    llamadas.add('eliminarYSeguir');
    return 2;
  }

  @override
  Future<void> dejarDeRepetir(int id) async => llamadas.add('dejarDeRepetir');

  @override
  Future<int?> marcarCumplido(int id) async {
    llamadas.add('cumplir');
    return null;
  }

  @override
  Future<void> actualizar(Recordatorio r) async => actualizado = r;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _app(_RepoFalso repo, Widget hijo) => ProviderScope(
      overrides: [recordatoriosRepoProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.claro(), home: Scaffold(body: hijo)),
    );

Widget _boton(void Function(BuildContext, WidgetRef) accion) => Consumer(
      builder: (context, ref, _) => Center(
        child: TextButton(
          onPressed: () => accion(context, ref),
          child: const Text('probar'),
        ),
      ),
    );

const _suelto = Recordatorio(id: 1, descripcion: 'Filtro', fecha: '2026-01-10');
const _repetido = Recordatorio(
  id: 1,
  descripcion: 'Aceite',
  fecha: '2026-01-10',
  repite: Repeticion.meses(1),
);

void main() {
  group('eliminar', () {
    Future<_RepoFalso> abrir(WidgetTester tester, Recordatorio r) async {
      final repo = _RepoFalso();
      await tester.pumpWidget(
        _app(repo, _boton((c, ref) => eliminarAviso(c, ref, r))),
      );
      await tester.tap(find.text('probar'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('uno suelto pide confirmar y avisa dónde queda', (t) async {
      final repo = await abrir(t, _suelto);

      expect(find.text('¿Eliminar este aviso?'), findsOneWidget);
      expect(find.text('Se queda en el historial como Eliminado.'),
          findsOneWidget);

      await t.tap(find.text('Aceptar'));
      await t.pumpAndSettle();
      expect(repo.llamadas, ['eliminar']);
    });

    testWidgets('cancelar no hace nada', (t) async {
      final repo = await abrir(t, _suelto);

      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(repo.llamadas, isEmpty);
    });

    testWidgets('uno repetido da las tres salidas en una ventana', (t) async {
      await abrir(t, _repetido);

      expect(find.text('Dejar de repetir'), findsOneWidget);
      expect(find.text('Eliminar solo este'), findsOneWidget);
      expect(find.text('Eliminar este y dejar de repetir'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'sin elegir no se puede aceptar',
      );
    });

    for (final (opcion, esperada) in const [
      ('Dejar de repetir', 'dejarDeRepetir'),
      ('Eliminar solo este', 'eliminarYSeguir'),
      ('Eliminar este y dejar de repetir', 'eliminar'),
    ]) {
      testWidgets('"$opcion" hace lo que dice', (t) async {
        final repo = await abrir(t, _repetido);

        await t.tap(find.text(opcion));
        await t.pump();
        await t.tap(find.text('Aceptar'));
        await t.pumpAndSettle();

        expect(repo.llamadas, [esperada]);
      });
    }
  });

  testWidgets('cumplir pregunta porque no se puede desmarcar', (t) async {
    final repo = _RepoFalso();
    await t.pumpWidget(
      _app(repo, _boton((c, ref) => cumplirAviso(c, ref, _suelto))),
    );
    await t.tap(find.text('probar'));
    await t.pumpAndSettle();
    expect(repo.llamadas, isEmpty);

    await t.tap(find.text('Aceptar'));
    await t.pumpAndSettle();
    expect(repo.llamadas, ['cumplir']);
  });

  testWidgets('editar no le quita la estrella', (t) async {
    final repo = _RepoFalso();
    await t.pumpWidget(ProviderScope(
      overrides: [recordatoriosRepoProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: FormularioRecordatorio(
          recordatorio: Recordatorio(
            id: 1,
            descripcion: 'Con estrella',
            fecha: '2026-12-10',
            importante: true,
          ),
        ),
      ),
    ));

    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();

    expect(repo.actualizado!.importante, isTrue);
  });

  group('la pantalla', () {
    final hoy = hoyISO();

    testWidgets('abre sola en Vencidos si hay', (t) async {
      final repo = _RepoFalso([
        Recordatorio(
          id: 1,
          descripcion: 'Atrasado',
          fecha: sumarDias(hoy, -3),
          estado: EstadoRecordatorio.vencido,
        ),
        Recordatorio(id: 2, descripcion: 'De hoy', fecha: hoy),
      ]);

      await t.pumpWidget(_app(repo, const PantallaRecordatorios()));
      await t.pumpAndSettle();

      expect(find.text('Atrasado'), findsOneWidget);
      expect(find.text('De hoy'), findsNothing);

      await t.tap(find.text('Hoy'));
      await t.pumpAndSettle();

      expect(find.text('De hoy'), findsOneWidget);
      expect(find.text('Atrasado'), findsNothing);
    });

    testWidgets('sin vencidos abre en Hoy', (t) async {
      final repo = _RepoFalso([
        Recordatorio(id: 2, descripcion: 'De hoy', fecha: hoy),
        Recordatorio(
          id: 3,
          descripcion: 'Más adelante',
          fecha: sumarDias(hoy, 20),
        ),
      ]);

      await t.pumpWidget(_app(repo, const PantallaRecordatorios()));
      await t.pumpAndSettle();

      expect(find.text('De hoy'), findsOneWidget);
      expect(find.text('Más adelante'), findsNothing);
    });
  });

  group('completados', () {
    testWidgets('el símbolo de año solo sale con dos años o más', (t) async {
      final anio = fechaDe(hoyISO()).year;
      final repo = _RepoFalso([
        Recordatorio(
          id: 1,
          descripcion: 'A',
          fecha: '$anio-01-05',
          estado: EstadoRecordatorio.cumplido,
        ),
      ]);

      await t.pumpWidget(_app(repo, const PantallaCompletados()));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      repo.items = [
        ...repo.items,
        Recordatorio(
          id: 2,
          descripcion: 'B',
          fecha: '${anio - 1}-03-05',
          estado: EstadoRecordatorio.cumplido,
        ),
      ];
      await t.pumpWidget(_app(repo, const SizedBox()));
      await t.pumpWidget(_app(repo, const PantallaCompletados()));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('un mes dice cuántos de cuántos y abre sus listas', (t) async {
      final anio = fechaDe(hoyISO()).year;
      final repo = _RepoFalso([
        Recordatorio(
          id: 1,
          descripcion: 'Hecho',
          fecha: '$anio-01-05',
          estado: EstadoRecordatorio.cumplido,
          cumplidoEl: '$anio-01-07',
        ),
        Recordatorio(
          id: 2,
          descripcion: 'Olvidado',
          fecha: '$anio-01-06',
          estado: EstadoRecordatorio.vencido,
        ),
        Recordatorio(
          id: 3,
          descripcion: 'Borrado',
          fecha: '$anio-01-08',
          estado: EstadoRecordatorio.eliminado,
          eliminadoEl: '$anio-01-09',
        ),
      ]);

      await t.pumpWidget(_app(repo, const PantallaCompletados()));
      await t.pumpAndSettle();

      expect(find.text('1 de 2 cumplidos'), findsOneWidget);

      await t.tap(find.text('Enero'));
      await t.pumpAndSettle();

      expect(find.text('CUMPLIDOS'), findsOneWidget);
      expect(find.text('Cumplido el 7 ene'), findsOneWidget);
      expect(find.text('SIN CUMPLIR'), findsOneWidget);
      expect(find.text('ELIMINADOS'), findsOneWidget);
      expect(find.text('Eliminado el 9 ene'), findsOneWidget);
      expect(find.text('Borrar para siempre'), findsOneWidget);
    });
  });
}
