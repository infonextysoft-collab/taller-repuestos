import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:sqflite_common/sqlite_api.dart';

/// De dónde sale el motor de SQLite en celular y escritorio.
///
/// En Android/iOS lo pone el sistema. En escritorio no hay motor propio, así
/// que se enchufa el de FFI. Este archivo **no** se compila para web: ver
/// `fabrica_db.dart`.
DatabaseFactory fabricaDb() {
  if (Platform.isAndroid || Platform.isIOS) return sqflite.databaseFactory;

  sqfliteFfiInit();
  return databaseFactoryFfi;
}

/// Dónde vive el archivo de la base.
Future<String> rutaDb(String archivo) async =>
    p.join(await fabricaDb().getDatabasesPath(), archivo);

/// Base en memoria, para los tests.
DatabaseFactory fabricaDbMemoria() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

String get rutaEnMemoria => inMemoryDatabasePath;
