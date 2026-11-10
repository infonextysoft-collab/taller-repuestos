import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/services/historial_avisos.dart';

void main() {
  const hoy = '2026-11-09';

  Recordatorio aviso(
    String fecha, {
    EstadoRecordatorio estado = EstadoRecordatorio.pendiente,
  }) =>
      Recordatorio(descripcion: 'x', fecha: fecha, estado: estado);

  Recordatorio cumplido(String fecha) =>
      aviso(fecha, estado: EstadoRecordatorio.cumplido);
  Recordatorio eliminado(String fecha) =>
      aviso(fecha, estado: EstadoRecordatorio.eliminado);
  Recordatorio vencido(String fecha) =>
      aviso(fecha, estado: EstadoRecordatorio.vencido);

  group('años', () {
    test('el año en curso está siempre, aunque esté vacío', () {
      expect(aniosDelHistorial(const [], hoy: hoy), [2026]);
      expect(aniosDelHistorial([cumplido('2025-03-01')], hoy: '2027-01-05'),
          [2027, 2025]);
    });

    test('van del más nuevo al más viejo y sin límite', () {
      final todos = [
        cumplido('2023-01-01'),
        cumplido('2024-01-01'),
        eliminado('2025-01-01'),
        vencido('2022-01-01'),
      ];
      expect(aniosDelHistorial(todos, hoy: hoy),
          [2026, 2025, 2024, 2023, 2022]);
    });

    test('lo que todavía no llegó no abre un año nuevo', () {
      expect(aniosDelHistorial([aviso('2027-02-01')], hoy: hoy), [2026]);
    });
  });

  test('la ficha cuenta lo cumplido del año por su fecha programada', () {
    final todos = [
      cumplido('2026-01-10'),
      cumplido('2026-11-01'),
      cumplido('2025-12-31'),
      vencido('2026-02-01'),
      eliminado('2026-02-02'),
    ];
    expect(cumplidosDelAnio(todos, 2026), 2);
    expect(cumplidosDelAnio(todos, 2025), 1);
  });

  group('meses', () {
    test('solo los que tienen algo, del más nuevo al más viejo', () {
      final todos = [
        cumplido('2026-03-10'),
        vencido('2026-10-01'),
        cumplido('2026-07-02'),
      ];
      expect(
        mesesDelAnio(todos, 2026, hoy: hoy).map((m) => m.clave),
        ['2026-10', '2026-07', '2026-03'],
      );
    });

    test('lo que no llegó no cuenta como sin cumplir', () {
      final todos = [
        cumplido('2026-11-02'),
        vencido('2026-11-05'),
        aviso('2026-11-09'),
        aviso('2026-11-20'),
      ];
      final m = mesesDelAnio(todos, 2026, hoy: hoy).single;

      expect(m.cumplidos.length, 1);
      expect(m.sinCumplir.length, 1);
      expect(m.cuantos, 2);
      expect(m.avance, 0.5);
    });

    test('un mes sin nada pasado no aparece', () {
      expect(mesesDelAnio([aviso('2026-12-20')], 2026, hoy: hoy), isEmpty);
    });

    test('los eliminados se listan pero no cuentan', () {
      final todos = [
        cumplido('2026-10-02'),
        eliminado('2026-10-05'),
        eliminado('2026-10-06'),
      ];
      final m = mesesDelAnio(todos, 2026, hoy: hoy).single;

      expect(m.eliminados.length, 2);
      expect(m.cuantos, 1);
      expect(m.avance, 1);
    });

    test('un mes con solo eliminados aparece sin dividir por cero', () {
      final m = mesesDelAnio([eliminado('2026-10-05')], 2026, hoy: hoy).single;

      expect(m.cuantos, 0);
      expect(m.avance, 0);
    });

    test('cada repetición cuenta aparte, en su propio mes', () {
      final todos = [
        cumplido('2026-08-10'),
        cumplido('2026-09-10'),
        vencido('2026-10-10'),
      ];
      final meses = mesesDelAnio(todos, 2026, hoy: hoy);

      expect(meses.length, 3);
      expect(meses.first.sinCumplir.length, 1);
    });
  });
}
