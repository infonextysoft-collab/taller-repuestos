import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/recordatorios_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/entities/repeticion.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/repositories/trabajos_repository.dart';

/// Pruebas de la capa de datos sobre una base en memoria. Verifican las reglas
/// que no se ven en la interfaz: correlativos, movimiento de stock y el ciclo
/// de los recordatorios.
void main() {
  late AppDatabase base;
  late InventarioRepositorySqlite inventario;
  late TrabajosRepositorySqlite trabajos;
  late RecordatoriosRepositorySqlite recordatorios;

  setUp(() async {
    base = await AppDatabase.enMemoria();
    inventario = InventarioRepositorySqlite(base);
    trabajos = TrabajosRepositorySqlite(base, inventario);
    recordatorios = RecordatoriosRepositorySqlite(base);
  });

  tearDown(() => base.cerrar());

  group('correlativo', () {
    test('numera por tipo y por año', () async {
      final a = await trabajos.crear(
          const Trabajo(tipo: TipoTrabajo.taller, fecha: '2026-03-04'));
      final b = await trabajos.crear(
          const Trabajo(tipo: TipoTrabajo.campo, fecha: '2026-05-10'));
      final c = await trabajos.crear(
          const Trabajo(tipo: TipoTrabajo.venta, fecha: '2026-05-10'));
      final d = await trabajos.crear(
          const Trabajo(tipo: TipoTrabajo.taller, fecha: '2027-01-02'));

      // Taller y campo comparten el prefijo REP; las ventas van por su cuenta.
      expect(a.codigo, 'REP-2026-0001');
      expect(b.codigo, 'REP-2026-0002');
      expect(c.codigo, 'VTA-2026-0001');
      expect(d.codigo, 'REP-2027-0001');
    });

    test('dos altas seguidas no repiten número', () async {
      final creados = await Future.wait([
        trabajos.crear(const Trabajo(fecha: '2026-03-04')),
        trabajos.crear(const Trabajo(fecha: '2026-03-04')),
      ]);

      expect(creados.map((t) => t.codigo).toSet().length, 2);
    });
  });

  group('stock', () {
    late int idMotor;

    setUp(() async {
      idMotor = await inventario.crear(
          const Repuesto(nombre: 'MOTOR', stock: 3, precio: 100));
    });

    test('agregar descuenta del inventario', () async {
      final r = await inventario.agregarRepuesto(
          inventarioId: idMotor, desc: 'MOTOR', cant: 2);

      expect(r.aviso, isNull);
      expect(r.lineas.single.cantidad, 2);
      expect(r.lineas.single.origen, OrigenRepuesto.inventario);
      expect((await inventario.obtener(idMotor))!.stock, 1);
    });

    test('sin stock suficiente la línea se divide sola y avisa', () async {
      final r = await inventario.agregarRepuesto(
          inventarioId: idMotor, desc: 'MOTOR', cant: 5);

      expect(r.lineas.length, 2);
      expect(r.lineas.first.cantidad, 3);
      expect(r.lineas.first.origen, OrigenRepuesto.inventario);
      expect(r.lineas.last.cantidad, 2);
      expect(r.lineas.last.origen, OrigenRepuesto.externo);
      expect(r.aviso, contains('Solo había 3'));
      expect((await inventario.obtener(idMotor))!.stock, 0);
    });

    test('sin inventarioId es una línea externa y no toca el stock', () async {
      final r = await inventario.agregarRepuesto(
          desc: 'Junta hecha a mano', cant: 1, precio: 15);

      expect(r.lineas.single.origen, OrigenRepuesto.externo);
      expect((await inventario.obtener(idMotor))!.stock, 3);
    });

    test('restaurar deja el stock como al abrir la pantalla', () async {
      final original = await inventario.agregarRepuesto(
          inventarioId: idMotor, desc: 'MOTOR', cant: 1);
      expect((await inventario.obtener(idMotor))!.stock, 2);

      // Durante la edición se agregó otra unidad...
      final actual = await inventario.agregarRepuesto(
          inventarioId: idMotor, desc: 'MOTOR', cant: 1);
      expect((await inventario.obtener(idMotor))!.stock, 1);

      // ...y se canceló: vuelve al estado que tenía al abrir.
      await inventario.restaurarRepuestos(
        [...original.lineas, ...actual.lineas],
        original.lineas,
      );
      expect((await inventario.obtener(idMotor))!.stock, 2);
    });

    test('borrar un trabajo devuelve sus repuestos al stock', () async {
      final r = await inventario.agregarRepuesto(
          inventarioId: idMotor, desc: 'MOTOR', cant: 2);

      final t = await trabajos.crear(Trabajo(
        tipo: TipoTrabajo.venta,
        fecha: hoyISO(),
        repuestos: r.lineas,
      ));

      expect((await inventario.obtener(idMotor))!.stock, 1);
      await trabajos.eliminar(t.id!);
      expect((await inventario.obtener(idMotor))!.stock, 3);
    });

    test('un código repetido se detecta antes de guardarlo', () async {
      await inventario.crear(
          const Repuesto(nombre: 'BUJIA', codigoBarras: '7501234567893'));

      expect(await inventario.codigoRepetido('7501234567893'), isTrue);
      expect(await inventario.codigoRepetido('0000000000000'), isFalse);
    });

    test('varios repuestos pueden quedar sin código', () async {
      // Un código vacío se guarda como NULL, y SQLite deja pasar varios NULL
      // en un índice único.
      await inventario.crear(const Repuesto(nombre: 'A', codigoBarras: ''));
      await inventario.crear(const Repuesto(nombre: 'B'));

      expect((await inventario.listar()).length, 3);
      expect(await inventario.buscarPorCodigo(''), isNull);
    });
  });

  group('pasos guardados', () {
    test('guardar en el paso 6 cierra del 1 al 6', () async {
      final t = await trabajos.crear(const Trabajo(fecha: '2026-03-04'));
      final guardado = await trabajos.guardarPasosHasta(t.id!, 6);

      expect(guardado.pasosGuardados, [1, 2, 3, 4, 5, 6]);
    });

    test('editar reabre solo ese paso', () async {
      final t = await trabajos.crear(const Trabajo(fecha: '2026-03-04'));
      await trabajos.guardarPasosHasta(t.id!, 4);
      final reabierto = await trabajos.editarPaso(t.id!, 2);

      expect(reabierto.pasosGuardados, [1, 3, 4]);
    });
  });

  group('historial', () {
    test('lo más reciente primero; a igual fecha, el último arriba', () async {
      await trabajos.crear(const Trabajo(fecha: '2026-03-01', cliente: 'Ana'));
      await trabajos.crear(const Trabajo(fecha: '2026-03-05', cliente: 'Beto'));
      await trabajos.crear(const Trabajo(fecha: '2026-03-05', cliente: 'Caro'));

      final lista = await trabajos.listar();
      expect(lista.map((t) => t.cliente).toList(), ['Caro', 'Beto', 'Ana']);
    });

    test('la búsqueda mira cliente y equipo, sin tildes', () async {
      await trabajos.crear(
          const Trabajo(fecha: '2026-03-01', cliente: 'Ana', equipo: 'Bujía'));
      await trabajos.crear(
          const Trabajo(fecha: '2026-03-02', cliente: 'Beto', equipo: 'Motor'));

      expect((await trabajos.listar(const FiltroHistorial(busqueda: 'bujia')))
          .single.cliente, 'Ana');
      expect((await trabajos.listar(const FiltroHistorial(busqueda: 'BETO')))
          .single.equipo, 'Motor');
    });
  });

  group('recordatorios', () {
    test('cumplir uno recurrente crea el siguiente desde la fecha programada',
        () async {
      final id = await recordatorios.crear(const Recordatorio(
        descripcion: 'Cambio de aceite',
        fecha: '2026-01-31',
        repite: Repeticion.meses(1),
      ));

      final siguienteId = await recordatorios.marcarCumplido(id);
      expect(siguienteId, isNotNull);

      final anterior = await recordatorios.obtener(id);
      expect(anterior!.estado, EstadoRecordatorio.cumplido);

      // Cuenta desde la fecha programada, no desde hoy, y cae al último día
      // del mes destino.
      final siguiente = await recordatorios.obtener(siguienteId!);
      expect(siguiente!.fecha, '2026-02-28');
    });

    test('cumplir uno que no se repite no crea nada', () async {
      final id = await recordatorios
          .crear(const Recordatorio(descripcion: 'Único', fecha: '2026-01-10'));

      expect(await recordatorios.marcarCumplido(id), isNull);
    });

    test('reprogramar un vencido para adelante lo devuelve a pendiente',
        () async {
      final id = await recordatorios.crear(Recordatorio(
        descripcion: 'Revisión',
        fecha: sumarMeses(hoyISO(), -2),
      ));

      expect((await recordatorios.obtener(id))!.estado,
          EstadoRecordatorio.vencido);
      expect(await recordatorios.contarVencidos(), 1);

      await recordatorios.actualizar(
        (await recordatorios.obtener(id))!.copyWith(
          fecha: sumarMeses(hoyISO(), 2),
        ),
      );

      expect((await recordatorios.obtener(id))!.estado,
          EstadoRecordatorio.pendiente);
      expect(await recordatorios.contarVencidos(), 0);
    });

    test('refrescarVencidos marca lo que ya pasó, y hoy no cuenta', () async {
      // Se crean con estado pendiente forzado escribiendo una fecha futura y
      // moviéndola después, que es lo que pasa cuando la app queda abierta.
      await recordatorios
          .crear(Recordatorio(descripcion: 'Hoy', fecha: hoyISO()));
      final vencido = await recordatorios.crear(
          Recordatorio(descripcion: 'Ayer', fecha: sumarMeses(hoyISO(), -1)));

      await recordatorios.refrescarVencidos();

      expect(await recordatorios.contarVencidos(), 1);
      expect((await recordatorios.obtener(vencido))!.estado,
          EstadoRecordatorio.vencido);
    });

    test('un cumplido nunca vuelve atrás', () async {
      final id = await recordatorios
          .crear(const Recordatorio(descripcion: 'Listo', fecha: '2026-01-10'));
      await recordatorios.marcarCumplido(id);

      await recordatorios.actualizar(
        (await recordatorios.obtener(id))!.copyWith(fecha: '2030-01-01'),
      );

      expect((await recordatorios.obtener(id))!.estado,
          EstadoRecordatorio.cumplido);
    });
  });
}
