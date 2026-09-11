import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/repositories/respaldo_repository.dart';

/// Guardar y recuperar todo.
///
/// Es la única red que hay contra perder el teléfono: la app guarda todo en el
/// dispositivo y no hay servidor de donde bajar nada. El archivo lo guarda la
/// persona donde quiera —Drive, el correo, mandándoselo por WhatsApp— y en un
/// teléfono nuevo lo importa y sigue como estaba.
class PantallaRespaldo extends ConsumerStatefulWidget {
  const PantallaRespaldo({super.key});

  @override
  ConsumerState<PantallaRespaldo> createState() => _PantallaRespaldoState();
}

class _PantallaRespaldoState extends ConsumerState<PantallaRespaldo> {
  ResumenRespaldo? _actual;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _contar();
  }

  Future<void> _contar() async {
    final resumen = await ref.read(respaldoRepoProvider).resumenActual();
    if (mounted) setState(() => _actual = resumen);
  }

  /* ------------------------------------------------------------- guardar */

  Future<void> _guardar() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);

    try {
      final bytes = await ref.read(respaldoRepoProvider).exportar();
      final nombre = 'respaldo-ms-${hoyISO()}.zip';

      // En el navegador no hay dónde escribir ni hoja para compartir; se baja
      // como cualquier archivo.
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'application/zip')],
            fileNameOverrides: [nombre],
          ),
        );
      } else {
        final carpeta = await getTemporaryDirectory();
        final archivo = File(p.join(carpeta.path, nombre));
        await archivo.writeAsBytes(bytes, flush: true);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(archivo.path, mimeType: 'application/zip')],
            subject: 'Respaldo de MS',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo armar el respaldo: $e',
            problema: true);
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  /* ----------------------------------------------------------- restaurar */

  Future<void> _restaurar() async {
    if (_trabajando) return;

    final elegido = await FilePicker.pickFile(type: FileType.any);
    if (elegido == null || !mounted) return;

    final bytes = await elegido.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    final seguro = await confirmar(
      context,
      titulo: '¿Restaurar este respaldo?',
      mensaje: 'Se reemplaza todo lo que hay en este teléfono por lo que traiga '
          'el archivo. Lo que cargaste después del respaldo se pierde.',
      aceptar: 'Restaurar',
      cancelar: 'Permanecer',
      destructivo: true,
    );
    if (!seguro || !mounted) return;

    setState(() => _trabajando = true);

    try {
      final resultado =
          await ref.read(respaldoRepoProvider).restaurar(bytes);
      if (!mounted) return;

      // Cambió todo: hay que rearmar cada pantalla y los datos del emisor.
      ref.read(refrescoHistorialProvider.notifier).state++;
      ref.read(refrescoInventarioProvider.notifier).state++;
      ref.read(refrescoRecordatoriosProvider.notifier).state++;
      ref.invalidate(vencidosProvider);
      await ref.read(negocioProvider.notifier).cargar();

      await _contar();
      if (!mounted) return;

      mostrarAviso(
        context,
        'Listo: ${resultado.trabajos} registros y ${resultado.fotos} fotos.',
      );
    } on RespaldoInvalido catch (e) {
      if (mounted) mostrarAviso(context, e.motivo, problema: true);
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo restaurar: $e', problema: true);
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  /* ---------------------------------------------------------------- vista */

  @override
  Widget build(BuildContext context) {
    final actual = _actual;

    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo')),
      body: ListView(
        padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
        children: [
          Contenido(
            ancho: Ancho.acciones,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Todo vive en este teléfono. Si se pierde o se rompe, el '
                  'respaldo es lo único que lo trae de vuelta.',
                  style: Tipo.secundario,
                ),
                const SizedBox(height: Espacio.xl),
                Text('EN ESTE TELÉFONO', style: Tipo.etiqueta),
                const SizedBox(height: Espacio.md),
                if (actual == null)
                  const Panel(child: Center(child: CircularProgressIndicator()))
                else
                  ListaAgrupada(
                    filas: [
                      _Cuenta('Registros', actual.trabajos),
                      _Cuenta('Repuestos', actual.repuestos),
                      _Cuenta('Recordatorios', actual.recordatorios),
                      _Cuenta('Fotos', actual.fotos),
                    ],
                  ),
                const SizedBox(height: Espacio.xl),
                FilledButton.icon(
                  onPressed: _trabajando ? null : _guardar,
                  icon: _trabajando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded, size: 20),
                  label: const Text('Guardar respaldo'),
                ),
                const SizedBox(height: Espacio.md),
                Text(
                  'Se abre para elegir dónde mandarlo. Guárdalo en Drive o '
                  'mándatelo por WhatsApp: lo importante es que no quede solo '
                  'en este teléfono.',
                  style: Tipo.nota,
                ),
                const SizedBox(height: Espacio.xxl),
                const Divider(height: 1),
                const SizedBox(height: Espacio.xxl),
                Text('TELÉFONO NUEVO', style: Tipo.etiqueta),
                const SizedBox(height: Espacio.md),
                Text(
                  'Restaurar reemplaza todo lo que haya aquí. Se usa al estrenar '
                  'un equipo, no para juntar dos.',
                  style: Tipo.secundario,
                ),
                const SizedBox(height: Espacio.lg),
                OutlinedButton.icon(
                  onPressed: _trabajando ? null : _restaurar,
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: const Text('Restaurar desde un archivo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta(this.que, this.cuantos);

  final String que;
  final int cuantos;

  @override
  Widget build(BuildContext context) => FilaLista(
        child: Row(
          children: [
            Expanded(child: Text(que, style: Tipo.cuerpo)),
            Text(
              '$cuantos',
              style: Tipo.monto.copyWith(
                color: cuantos == 0 ? Tono.texto3 : Tono.texto,
              ),
            ),
          ],
        ),
      );
}
