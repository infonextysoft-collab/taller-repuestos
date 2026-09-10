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

/// El documento en pantalla.
///
/// Se muestra el PDF de verdad, no una imitación en widgets: lo que se ve es
/// exactamente lo que se va a entregar.
///
/// Una sola acción a la vista: **descargar**. Imprimir y compartir estaban de
/// más — el papel se manda por WhatsApp desde el archivo ya bajado, y una barra
/// con tres íconos obliga a elegir antes de hacer lo único que se hace siempre.
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
  bool _descargando = false;

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
      if (t.tipo.llevaReporte) 'Reporte de servicio',
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
      aceptar: 'Eliminar',
      cancelar: 'Permanecer',
      destructivo: true,
    );
    if (!seguro || !mounted) return;

    await ref.read(trabajosRepoProvider).eliminar(t.id!);
    if (!mounted) return;

    ref.read(refrescoHistorialProvider.notifier).state++;
    ref.read(refrescoInventarioProvider.notifier).state++;
    Navigator.of(context).pop();
  }

  /// Baja el documento **completo** —reporte y boleta(s)— y no solo la
  /// pestaña abierta: es un solo papel para el cliente.
  Future<void> _descargar() async {
    if (_descargando) return;
    setState(() => _descargando = true);

    try {
      final t = _trabajo!;
      final bytes = await ref
          .read(generadorPdfProvider)
          .completo(t, ref.read(negocioProvider));

      await Printing.sharePdf(bytes: bytes, filename: '${t.codigo}.pdf');
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo generar el PDF: $e', problema: true);
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
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
            child: FilledButton.icon(
              onPressed: _descargando ? null : _descargar,
              icon: _descargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                _descargando ? 'Generando…' : 'Descargar PDF',
              ),
            ),
          ),
        ),
      ),
    );
  }
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
