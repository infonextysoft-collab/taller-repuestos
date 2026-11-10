import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/presentation/features/reportes/filtro_reportes.dart';

/// Qué entra y qué no en los números de Reportes.
void main() {
  final hoy = hoyISO();
  final esteMes = claveMes(hoy);
  final esteAnio = hoy.substring(0, 4);

  test('este mes deja pasar solo las fechas del mes corriente', () {
    const f = FiltroReporte();

    expect(f.entra('$esteMes-01'), isTrue);
    expect(f.entra('${int.parse(esteAnio) - 1}-01-15'), isFalse);
  });

  test('este año deja pasar cualquier mes del año corriente', () {
    const f = FiltroReporte(periodo: PeriodoReporte.anio);

    expect(f.entra('$esteAnio-01-01'), isTrue);
    expect(f.entra('$esteAnio-12-31'), isTrue);
    expect(f.entra('${int.parse(esteAnio) - 1}-12-31'), isFalse);
  });

  test('todo no filtra nada', () {
    const f = FiltroReporte(periodo: PeriodoReporte.todo);

    expect(f.entra('2020-01-01'), isTrue);
    expect(f.entra('2099-12-31'), isTrue);
  });

  group('entre dos fechas', () {
    const f = FiltroReporte(
      periodo: PeriodoReporte.rango,
      desde: '2026-09-01',
      hasta: '2026-09-15',
    );

    test('las dos puntas van incluidas', () {
      expect(f.entra('2026-09-01'), isTrue);
      expect(f.entra('2026-09-15'), isTrue);
    });

    test('lo de afuera queda afuera', () {
      expect(f.entra('2026-08-31'), isFalse);
      expect(f.entra('2026-09-16'), isFalse);
    });

    test('una sola punta no cierra el otro lado', () {
      const soloDesde =
          FiltroReporte(periodo: PeriodoReporte.rango, desde: '2026-09-01');

      expect(soloDesde.entra('2030-01-01'), isTrue);
      expect(soloDesde.entra('2026-08-31'), isFalse);
    });
  });

  group('el rótulo del botón', () {
    test('un rango completo se lee como dos fechas', () {
      const f = FiltroReporte(
        periodo: PeriodoReporte.rango,
        desde: '2026-09-01',
        hasta: '2026-09-15',
      );

      expect(f.etiqueta, '01/09/2026 – 15/09/2026');
    });

    test('con una sola punta lo dice con palabras', () {
      const desde =
          FiltroReporte(periodo: PeriodoReporte.rango, desde: '2026-09-01');
      const hasta =
          FiltroReporte(periodo: PeriodoReporte.rango, hasta: '2026-09-15');

      expect(desde.etiqueta, 'Desde 01/09/2026');
      expect(hasta.etiqueta, 'Hasta 15/09/2026');
    });

    test('el año corriente se rotula con el año', () {
      const f = FiltroReporte(periodo: PeriodoReporte.anio);

      expect(f.etiqueta, esteAnio);
    });
  });
}
