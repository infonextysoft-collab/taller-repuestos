import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/documentos/generador_pdf.dart';
import '../data/fotos/servicio_fotos.dart';
import '../data/local/app_database.dart';
import '../data/repositories/auth_repository_sqlite.dart';
import '../data/repositories/inventario_repository_sqlite.dart';
import '../data/repositories/negocio_repository_sqlite.dart';
import '../data/repositories/recordatorios_repository_sqlite.dart';
import '../data/repositories/trabajos_repository_sqlite.dart';
import '../data/respaldo/respaldo_zip.dart';
import '../domain/entities/negocio.dart';
import '../domain/entities/resumen_taller.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/inventario_repository.dart';
import '../domain/repositories/negocio_repository.dart';
import '../domain/repositories/recordatorios_repository.dart';
import '../domain/repositories/respaldo_repository.dart';
import '../domain/repositories/trabajos_repository.dart';

/// El cableado de la app: qué implementación concreta usa cada contrato.
///
/// Es el único archivo que conoce las dos capas a la vez. Cambiar SQLite por
/// otra cosa —o meter un backup en la nube— se hace acá y en `data/`, sin que
/// una sola pantalla se entere.

/// Se resuelve en `main()`, cuando la base ya está abierta.
final baseDatosProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Sobrescribir en main() con la base abierta'),
);

final inventarioRepoProvider = Provider<InventarioRepository>(
  (ref) => InventarioRepositorySqlite(ref.watch(baseDatosProvider)),
);

final trabajosRepoProvider = Provider<TrabajosRepository>(
  (ref) => TrabajosRepositorySqlite(
    ref.watch(baseDatosProvider),
    ref.watch(inventarioRepoProvider),
  ),
);

final recordatoriosRepoProvider = Provider<RecordatoriosRepository>(
  (ref) => RecordatoriosRepositorySqlite(ref.watch(baseDatosProvider)),
);

final negocioRepoProvider = Provider<NegocioRepository>(
  (ref) => NegocioRepositorySqlite(ref.watch(baseDatosProvider)),
);

final respaldoRepoProvider = Provider<RespaldoRepository>(
  (ref) => RespaldoZip(ref.watch(baseDatosProvider)),
);

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepositorySqlite(ref.watch(baseDatosProvider)),
);

/// Quien dibuja el papel. No tiene estado: una sola instancia alcanza.
final generadorPdfProvider = Provider<GeneradorPdf>((ref) => GeneradorPdf());

/// Cámara, galería y compresión de las fotos del trabajo.
final servicioFotosProvider = Provider<ServicioFotos>((ref) => ServicioFotos());

/// Datos del emisor. Los lee la TopBar y los documentos, así que vive acá
/// arriba y no dentro de una pantalla.
class NegocioNotifier extends StateNotifier<Negocio> {
  NegocioNotifier(this._repo) : super(const Negocio()) {
    cargar();
  }

  final NegocioRepository _repo;

  Future<void> cargar() async {
    state = await _repo.obtener();
  }

  Future<void> guardar(Negocio negocio) async {
    state = await _repo.guardar(negocio);
  }
}

final negocioProvider =
    StateNotifierProvider<NegocioNotifier, Negocio>(
  (ref) => NegocioNotifier(ref.watch(negocioRepoProvider)),
);

/// Cuántos recordatorios están vencidos. Lo mira el aviso de la TopBar y el
/// punto rojo del BottomNav.
final vencidosProvider = FutureProvider<int>((ref) async {
  ref.watch(refrescoRecordatoriosProvider);
  return ref.watch(recordatoriosRepoProvider).contarVencidos();
});

/// Lo que hay que atender: mantenimientos que vencen, registros sin cerrar y
/// repuestos agotados. Lo miran las tarjetas de arriba del Historial.
///
/// Mira los tres contadores de refresco porque cruza las tres tablas: cerrar un
/// trabajo, marcar un mantenimiento o vender el último repuesto cambian lo que
/// muestra, y ninguna de esas pantallas tiene por qué saber que existe.
final resumenProvider = FutureProvider<ResumenTaller>((ref) async {
  ref.watch(refrescoRecordatoriosProvider);
  ref.watch(refrescoHistorialProvider);
  ref.watch(refrescoInventarioProvider);

  final recordatorios = await ref.watch(recordatoriosRepoProvider).listar();
  final trabajos = await ref.watch(trabajosRepoProvider).listar();
  final inventario = await ref.watch(inventarioRepoProvider).listar();

  return ResumenTaller.de(
    recordatorios: recordatorios,
    trabajos: trabajos,
    inventario: inventario,
  );
});

/// Un pedido de "abrí el inventario mostrando lo agotado".
///
/// Es un contador y no un booleano a propósito: si fuera booleano, volver a
/// pedir lo mismo dos veces seguidas no cambiaría el valor y la pantalla no se
/// enteraría de la segunda vez.
final pedidoAgotadosProvider = StateProvider<int>((ref) => 0);

/// Se incrementa cuando algo cambia en recordatorios, para que las vistas que
/// dependen del conteo se rearmen sin acoplarse entre ellas.
final refrescoRecordatoriosProvider = StateProvider<int>((ref) => 0);

/// Lo mismo para el inventario: lo miran la lista y el selector de repuestos.
final refrescoInventarioProvider = StateProvider<int>((ref) => 0);

/// Y para el historial.
final refrescoHistorialProvider = StateProvider<int>((ref) => 0);
