import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/avisos.dart';
import '../../../domain/entities/totales.dart';
import '../../../domain/entities/trabajo.dart';
import '../../../domain/services/calculadora_totales.dart';
import '../../comunes/elegir_documentos.dart';

enum _Salida { descargar, compartir }

/// El documento en pantalla.
///
/// Se muestra el PDF de verdad, no una imitación en widgets: lo que se ve es
/// exactamente lo que se va a entregar.
///
/// Abajo, dos salidas: **descargar**, grande, que deja el PDF en el teléfono,
/// y **compartir**, al lado y más chico, que lo manda directo por WhatsApp o
/// correo. Son cosas distintas y cada una hace lo que dice. Imprimir no está:
/// el papel sale desde el archivo ya bajado.
///
/// Eliminar vive acá arriba, detrás del menú, y ya no en la lista del
/// historial. Borrar un registro por error es caro —los repuestos vuelven al
/// inventario y el correlativo queda con un hueco— así que la acción tiene que
/// costar abrir el registro primero, no un toque al pasar.
class PantallaDocumento extends ConsumerStatefulWidget {
  const PantallaDocumento({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PantallaDocumento> createState() => _PantallaDocumentoState();
}

class _PantallaDocumentoState extends ConsumerState<PantallaDocumento> {
  Trabajo? _trabajo;
  List<Boleta> _boletas = const [];
  int _pestana = 0;

  /// La salida que se está armando. Mientras hay una, las dos quedan quietas:
  /// dos toques seguidos no pueden generar dos PDF.
  _Salida? _enCurso;

  /// Desde que se toca el botón hasta que termina, ventana incluida.
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final t = await ref.read(trabajosRepoProvider).obtener(widget.id);
    if (!mounted || t == null) return;

    setState(() {
      _trabajo = t;
      _boletas = calculadora.calcularBoletas(t);
    });
  }

  /// Las pestañas: el reporte —si lo hay— y una por boleta.
  List<String> get _pestanas {
    final t = _trabajo;
    if (t == null) return const [];
    return [
      // Una venta simple no lleva reporte: no hubo servicio que reportar.
      if (t.tipo.llevaReporte) 'Reporte de trabajo',
      for (final b in _boletas) b.titulo,
    ];
  }

  Future<Uint8List> _pdfDe(int pestana) {
    final t = _trabajo!;
    final negocio = ref.read(negocioProvider);
    final pdf = ref.read(generadorPdfProvider);

    if (t.tipo.llevaReporte && pestana == 0) {
      return pdf.soloReporte(t, negocio);
    }
    final indice = t.tipo.llevaReporte ? pestana - 1 : pestana;
    return pdf.soloBoleta(t, negocio, indice);
  }

  Future<void> _eliminar() async {
    final t = _trabajo!;

    final seguro = await confirmar(
      context,
      titulo: '¿Eliminar ${t.codigo}?',
      mensaje: 'No se puede deshacer. Los repuestos que tenía cargados vuelven '
          'al inventario.',
      destructivo: true,
    );
    if (!seguro || !mounted) return;

    await ref.read(trabajosRepoProvider).eliminar(t.id!);
    if (!mounted) return;

    ref.read(refrescoHistorialProvider.notifier).state++;
    ref.read(refrescoInventarioProvider.notifier).state++;
    Navigator.of(context).pop();
  }

  /// Pregunta qué papeles van y saca esos, sin importar qué pestaña esté
  /// abierta: el dueño del vehículo y el contador no reciben lo mismo.
  Future<void> _sacar(_Salida salida) async {
    if (_ocupado) return;
    _ocupado = true;

    try {
      await sacarDocumentos(
        context,
        ref,
        _trabajo!,
        compartir: salida == _Salida.compartir,
        alArmar: () {
          if (mounted) setState(() => _enCurso = salida);
        },
      );
    } finally {
      _ocupado = false;
      if (mounted) setState(() => _enCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _trabajo;

    if (t == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pestanas = _pestanas;
    final activa = _pestana.clamp(0, pestanas.length - 1);
    final conPago = ref.watch(negocioProvider).datosPago.isNotEmpty;

    return Scaffold(
      backgroundColor: Tono.fondo2,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.codigo, style: Tipo.encabezado),
            Text(
              t.cliente.trim().isEmpty ? 'Sin cliente' : t.cliente.trim(),
              style: Tipo.nota,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Más',
            color: Tono.negro,
            elevation: 12,
            shape: const RoundedRectangleBorder(
              borderRadius: Redondeo.brNormal,
            ),
            icon: const Icon(Icons.more_vert_rounded, color: Tono.texto2),
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: _eliminar,
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 19, color: Tono.oroClaro),
                    const SizedBox(width: Espacio.md),
                    Text(
                      'Eliminar registro',
                      style: Tipo.encabezado.copyWith(
                        fontSize: 15,
                        color: Tono.textoInverso,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: pestanas.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Tono.linea)),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      Espacio.lg,
                      Espacio.sm,
                      Espacio.lg,
                      Espacio.md,
                    ),
                    itemCount: pestanas.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Espacio.sm),
                    itemBuilder: (context, i) => _Pestana(
                      texto: pestanas[i],
                      activa: activa == i,
                      onTap: () => setState(() => _pestana = i),
                    ),
                  ),
                ),
              ),
      ),
      body: PdfPreview(
        // La clave fuerza a rearmar el PDF al cambiar de pestaña.
        key: ValueKey('${t.id}-$activa'),
        build: (_) => _pdfDe(activa),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        previewPageMargin: const EdgeInsets.all(Espacio.lg),
        scrollViewDecoration: const BoxDecoration(color: Tono.fondo2),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Tono.fondo,
          border: Border(top: BorderSide(color: Tono.linea)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Espacio.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _enCurso != null
                            ? null
                            : () => _sacar(_Salida.descargar),
                        icon: _enCurso == _Salida.descargar
                            ? const _Girando(color: Colors.white)
                            : const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          _enCurso == _Salida.descargar
                              ? 'Generando…'
                              : 'Descargar PDF',
                        ),
                      ),
                    ),
                    const SizedBox(width: Espacio.md),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: Tooltip(
                        message: 'Compartir',
                        child: OutlinedButton(
                          onPressed: _enCurso != null
                              ? null
                              : () => _sacar(_Salida.compartir),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: Tono.vino,
                          ),
                          child: _enCurso == _Salida.compartir
                              ? const _Girando(color: Tono.vino)
                              : const Icon(Icons.share_rounded, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                // Se avisa porque no se ve: el texto queda copiado aunque
                // WhatsApp lo descarte al mandar el PDF.
                if (conPago) ...[
                  const SizedBox(height: Espacio.md),
                  Text(
                    'Compartir copia tus datos de pago para pegarlos en el '
                    'chat.',
                    textAlign: TextAlign.center,
                    style: Tipo.nota,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Girando extends StatelessWidget {
  const _Girando({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
          decoration: BoxDecoration(
            color: activa ? Tono.vino : Tono.fondo2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: Tipo.nota.copyWith(
              fontSize: 13.5,
              color: activa ? Tono.textoInverso : Tono.texto2,
            ),
          ),
        ),
      );
}
