import 'dart:typed_data';

/// Qué hay adentro de un respaldo, para poder contarlo antes y después.
class ResumenRespaldo {
  const ResumenRespaldo({
    this.trabajos = 0,
    this.repuestos = 0,
    this.recordatorios = 0,
    this.fotos = 0,
    this.fecha = '',
  });

  final int trabajos;
  final int repuestos;
  final int recordatorios;
  final int fotos;

  /// Cuándo se armó el archivo, ISO corto. Vacío en el resumen de lo actual.
  final String fecha;

  bool get vacio =>
      trabajos == 0 && repuestos == 0 && recordatorios == 0 && fotos == 0;
}

/// Se lanza cuando el archivo no sirve, con un motivo que se le puede mostrar
/// a una persona tal cual.
class RespaldoInvalido implements Exception {
  const RespaldoInvalido(this.motivo);
  final String motivo;

  @override
  String toString() => motivo;
}

/// Copia de seguridad de todo, en un solo archivo.
///
/// Existe porque la app guarda todo en el dispositivo: si el teléfono se pierde
/// o se rompe, **no hay de dónde recuperar nada**. Esto es lo que tapa ese
/// agujero sin servidor, sin cuenta y sin costo — la persona guarda el archivo
/// donde quiera y lo importa en el teléfono nuevo.
abstract class RespaldoRepository {
  /// Arma el archivo con todo lo guardado, fotos incluidas.
  Future<Uint8List> exportar();

  /// **Reemplaza** todo lo que hay con lo que trae el archivo.
  ///
  /// No mezcla: restaurar es volver a un momento, y fusionar dos historiales
  /// con correlativos propios dejaría códigos repetidos en los documentos.
  Future<ResumenRespaldo> restaurar(Uint8List archivo);

  /// Qué hay hoy en el dispositivo.
  Future<ResumenRespaldo> resumenActual();
}
