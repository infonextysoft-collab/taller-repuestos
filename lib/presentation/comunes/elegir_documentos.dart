import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tipografia.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dinero.dart';
import '../../core/widgets/avisos.dart';
import '../../core/widgets/hoja.dart';
import '../../domain/entities/totales.dart';
import '../../domain/entities/trabajo.dart';
import '../../domain/services/calculadora_totales.dart';
import 'salida_pdf.dart';

/// Qué papeles salen en el PDF.
class SeleccionDocumentos {
  const SeleccionDocumentos({required this.reporte, required this.notas});

  final bool reporte;

  /// Las posiciones de las notas de venta marcadas.
  final List<int> notas;

  /// El nombre del archivo dice qué lleva adentro: el dueño del vehículo y el
  /// contador reciben papeles distintos del mismo trabajo, y en el chat los
  /// dos adjuntos se ven iguales.
  String nombreDeArchivo(Trabajo t, List<int> disponibles) {
    final todasLasNotas = notas.length == disponibles.length;

    if (todasLasNotas && (reporte || !t.tipo.llevaReporte)) {
      return '${t.codigo}.pdf';
    }
    if (notas.isEmpty) return '${t.codigo} - Reporte de trabajo.pdf';

    final parte = notas.length == 1 && disponibles.length > 1
        ? ' ${disponibles.indexOf(notas.first) + 1} de ${disponibles.length}'
        : '';

    if (reporte) return '${t.codigo} - Reporte y nota de venta$parte.pdf';
    if (notas.length > 1) return '${t.codigo} - Notas de venta.pdf';
    return '${t.codigo} - Nota de venta$parte.pdf';
  }
}

/// Las notas de venta que vale la pena ofrecer: en el modo separado, si el
/// trabajo no llevó repuestos, la de repuestos sería un papel en cero.
List<int> notasDisponibles(List<Boleta> notas) {
  final conAlgo = [
    for (var i = 0; i < notas.length; i++)
      if (notas[i].subtotal > 0) i,
  ];
  return conAlgo.isEmpty ? List.generate(notas.length, (i) => i) : conAlgo;
}

/// Pregunta qué papeles sacar. `null` si se cerró la ventana sin elegir.
///
/// Si solo hay un papel posible —una venta simple— no pregunta: una ventana
/// con una sola casilla es un toque de más.
Future<SeleccionDocumentos?> elegirDocumentos(
  BuildContext context,
  Trabajo t,
  List<Boleta> notas, {
  required bool compartir,
}) {
  final disponibles = notasDisponibles(notas);
  final conReporte = t.tipo.llevaReporte;

  if (!conReporte && disponibles.length <= 1) {
    return Future.value(
      SeleccionDocumentos(reporte: false, notas: disponibles),
    );
  }

  return mostrarHoja<SeleccionDocumentos>(
    context,
    titulo: compartir ? '¿Qué quieres compartir?' : '¿Qué quieres descargar?',
    bajada: t.codigo,
    contenido: (hoja) => _Casillas(
      conReporte: conReporte,
      notas: notas,
      disponibles: disponibles,
      compartir: compartir,
    ),
  );
}

/// Pregunta qué papeles sacar, arma ese PDF y lo descarga o lo comparte.
///
/// [alArmar] avisa cuando ya se eligió y empieza a generarse, que es lo que
/// tarda: mientras la ventana está abierta no hay nada que esperar.
Future<void> sacarDocumentos(
  BuildContext context,
  WidgetRef ref,
  Trabajo t, {
  required bool compartir,
  VoidCallback? alArmar,
}) async {
  final notas = calculadora.calcularBoletas(t);
  final eleccion = await elegirDocumentos(
    context,
    t,
    notas,
    compartir: compartir,
  );
  if (eleccion == null || !context.mounted) return;

  alArmar?.call();

  try {
    final negocio = ref.read(negocioProvider);
    final bytes = await ref
        .read(generadorPdfProvider)
        .seleccion(
          t,
          negocio,
          conReporte: eleccion.reporte,
          notas: eleccion.notas,
        );
    final nombre = eleccion.nombreDeArchivo(t, notasDisponibles(notas));

    if (compartir) {
      // Sin notas no hay nada que cobrar: el reporte solo no lleva mensaje.
      await compartirPdf(
        bytes,
        nombre,
        mensaje: eleccion.notas.isEmpty
            ? ''
            : mensajeDeEnvio(
                t,
                negocio,
                total: redondear(
                  eleccion.notas.fold<double>(
                    0,
                    (suma, i) => suma + notas[i].total,
                  ),
                ),
              ),
      );
    } else if (context.mounted) {
      await descargarPdf(context, bytes, nombre);
    }
  } catch (e) {
    if (context.mounted) {
      mostrarAviso(context, 'No se pudo sacar el PDF: $e', problema: true);
    }
  }
}

class _Casillas extends StatefulWidget {
  const _Casillas({
    required this.conReporte,
    required this.notas,
    required this.disponibles,
    required this.compartir,
  });

  final bool conReporte;
  final List<Boleta> notas;
  final List<int> disponibles;
  final bool compartir;

  @override
  State<_Casillas> createState() => _CasillasState();
}

class _CasillasState extends State<_Casillas> {
  late bool _reporte = widget.conReporte;
  late final Set<int> _notas = widget.disponibles.toSet();

  bool get _algoMarcado => _reporte || _notas.isNotEmpty;

  void _aceptar() {
    Navigator.of(context).pop(
      SeleccionDocumentos(
        reporte: _reporte,
        // En el orden del documento, no en el orden en que se marcaron.
        notas: widget.disponibles.where(_notas.contains).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Espacio.xl, 0, Espacio.xl, Espacio.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.conReporte)
          _Casilla(
            texto: 'Reporte de trabajo',
            marcada: _reporte,
            onCambio: (v) => setState(() => _reporte = v),
          ),
        for (final i in widget.disponibles)
          _Casilla(
            texto: widget.notas[i].titulo,
            marcada: _notas.contains(i),
            onCambio: (v) => setState(() {
              if (v) {
                _notas.add(i);
              } else {
                _notas.remove(i);
              }
            }),
          ),
        const SizedBox(height: Espacio.lg),
        FilledButton.icon(
          onPressed: _algoMarcado ? _aceptar : null,
          icon: Icon(
            widget.compartir ? Icons.share_rounded : Icons.download_rounded,
            size: 20,
          ),
          label: Text(widget.compartir ? 'Compartir' : 'Descargar'),
        ),
      ],
    ),
  );
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.texto,
    required this.marcada,
    required this.onCambio,
  });

  final String texto;
  final bool marcada;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: marcada,
    onChanged: (v) => onCambio(v ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    activeColor: Tono.vino,
    title: Text(texto, style: Tipo.encabezado),
  );
}
