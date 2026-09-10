import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

export 'package:sqflite_common/sqlite_api.dart';

/// El mismo SQLite, compilado a WebAssembly y guardado en IndexedDB.
///
/// Esto existe para poder **probar la app en el navegador** mientras se
/// desarrolla: el destino real es el celular. Los datos de acá no son los del
/// celular — cada dispositivo tiene su propia base, que es justamente lo que
/// pide una app que funciona sin internet.
/// Sin *shared worker*: el motor corre en el hilo principal y guarda en
/// IndexedDB. El worker da mejor rendimiento, pero cuando falla lo hace en
/// silencio —los errores de un SharedWorker no llegan a la consola de la
/// página— y esto es una vista previa de desarrollo, no el destino real.
DatabaseFactory fabricaDb() => databaseFactoryFfiWebNoWebWorker;

/// En web no hay rutas de archivo: el nombre alcanza como identificador.
Future<String> rutaDb(String archivo) async => archivo;

DatabaseFactory fabricaDbMemoria() => databaseFactoryFfiWebNoWebWorker;

String get rutaEnMemoria => ':memory:';
