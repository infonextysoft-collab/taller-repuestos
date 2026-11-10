import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/negocio_repository_sqlite.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';

void main() {
  late AppDatabase base;

  setUp(() async => base = await AppDatabase.enMemoria());
  tearDown(() => base.cerrar());

  // RUC de ejemplo: el de verdad no se escribe en el repositorio.
  const fijo = '20131312955';

  test('con RUC fijo manda ese, aunque en la base haya otro', () async {
    await NegocioRepositorySqlite(base, rucFijo: '')
        .guardar(const Negocio(nombre: 'Taller', ruc: '20100000001'));

    final negocio = await NegocioRepositorySqlite(base, rucFijo: fijo).obtener();

    expect(negocio.ruc, fijo);
    expect(negocio.nombre, 'Taller');
  });

  test('con la base vacía también lo trae', () async {
    expect((await NegocioRepositorySqlite(base, rucFijo: fijo).obtener()).ruc,
        fijo);
  });

  test('sin RUC fijo se usa el que se guardó', () async {
    final repo = NegocioRepositorySqlite(base, rucFijo: '');
    await repo.guardar(const Negocio(nombre: 'Taller', ruc: '20100000001'));

    expect((await repo.obtener()).ruc, '20100000001');
  });
}
