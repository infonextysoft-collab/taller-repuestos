import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';
import 'package:taller_repuestos/domain/entities/resumen_taller.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';

void main() {
  final hoy = hoyISO();
  final ayer = sumarDias(hoy, -1);
  final anteayer = sumarDias(hoy, -2);
  final manana = sumarDias(hoy, 1);
  final enUnMes = sumarDias(hoy, 30);

  ResumenTaller armar({
    List<Recordatorio> recordatorios = const [],
    List<Trabajo> trabajos = const [],
    List<Repuesto> inventario = const [],
  }) =>
      ResumenTaller.de(
        recordatorios: recordatorios,
        trabajos: trabajos,
        inventario: inventario,
      );

  group('lo que toca hoy', () {
    test('incluye lo vencido, no solo lo de hoy', () {
      // Un vencido no deja de ser cosa de hoy por haber pasado de fecha: es lo
      // primero que hay que resolver.
      final r = armar(recordatorios: [
        Recordatorio(descripcion: 'Vencido', fecha: ayer),
        Recordatorio(descripcion: 'De hoy', fecha: hoy),
        Recordatorio(descripcion: 'Futuro', fecha: manana),
      ]);

      expect(r.pendientesHoy.map((x) => x.descripcion), ['Vencido', 'De hoy']);
    });

    test('el más viejo va primero', () {
      final r = armar(recordatorios: [
        Recordatorio(descripcion: 'Ayer', fecha: ayer),
        Recordatorio(descripcion: 'Anteayer', fecha: anteayer),
      ]);

      expect(r.pendientesHoy.first.descripcion, 'Anteayer');
    });

    test('un cumplido no cuenta aunque su fecha ya pasó', () {
      final r = armar(recordatorios: [
        Recordatorio(
          descripcion: 'Ya lo hice',
          fecha: ayer,
          estado: EstadoRecordatorio.cumplido,
        ),
      ]);

      expect(r.pendientesHoy, isEmpty);
      expect(r.alDia, isTrue);
    });
  });

  group('sin cerrar', () {
    test('solo los que no están terminados, del más viejo al más nuevo', () {
      final r = armar(trabajos: const [
        Trabajo(cliente: 'Nuevo', fecha: '2026-09-08'),
        Trabajo(
          cliente: 'Cerrado',
          fecha: '2026-09-01',
          estado: EstadoTrabajo.terminado,
        ),
        Trabajo(cliente: 'Viejo', fecha: '2026-09-02'),
      ]);

      expect(r.sinCerrar.map((t) => t.cliente), ['Viejo', 'Nuevo']);
    });
  });

  group('sin stock', () {
    test('solo lo agotado', () {
      final r = armar(inventario: const [
        Repuesto(nombre: 'Faja', stock: 0),
        Repuesto(nombre: 'Filtro', stock: 4),
      ]);

      expect(r.sinStock.single.nombre, 'Faja');
    });
  });

  group('al día', () {
    test('sin nada pendiente, ofrece la próxima fecha agendada', () {
      final r = armar(recordatorios: [
        Recordatorio(descripcion: 'Lejano', fecha: enUnMes),
        Recordatorio(descripcion: 'Próximo', fecha: manana),
      ]);

      expect(r.alDia, isTrue);
      // La más cercana de las futuras, no la primera de la lista.
      expect(r.proximoMantenimiento, manana);
    });

    test('con algo pendiente ya no está al día', () {
      final r = armar(inventario: const [Repuesto(nombre: 'Faja')]);
      expect(r.alDia, isFalse);
    });
  });
}
