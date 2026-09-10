/// Elige el motor de SQLite según dónde esté corriendo la app.
///
/// La importación es condicional a propósito: `dart:io` no existe en el
/// navegador, así que si el archivo de escritorio entrara al bundle web la app
/// ni siquiera llegaría a dibujar la primera pantalla. Este archivo es la
/// costura, y es el único lugar donde la app sabe que hay más de una
/// plataforma.
library;

export 'fabrica_db_io.dart' if (dart.library.js_interop) 'fabrica_db_web.dart';
