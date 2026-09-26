import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/repuesto.dart';
import '../../../domain/services/estadisticas.dart';

/// Lo que se puede hacer con un repuesto desde su ficha.
enum AccionRepuesto { editar, eliminar }

/// La ficha de un repuesto: todo lo que se sabe de él.
///
/// La lista del inventario quedó para **consultar** —buscar y ver stock— y
/// esto es el detalle. Editar es la única acción: ahí se cambian los precios,
/// el proveedor y también el stock, que es como se corrige un conteo.
///
/// Eliminar vive acá adentro y no en la fila: estaba a un toque de distancia
/// de borrar un repuesto sin querer.
Future<AccionRepuesto?> mostrarFichaRepuesto(
  BuildContext context,
  Repuesto repuesto,
) =>
    mostrarHoja<AccionRepuesto>(
      context,
      titulo: repuesto.nombre,
      bajada: repuesto.agotado
          ? 'Agotado'
          : '${repuesto.stock} en stock · ${soles(repuesto.precio)}',
      contenido: (hoja) => _Ficha(
        repuesto: repuesto,
        onAccion: (accion) => Navigator.of(hoja).pop(accion),
      ),
    );

class _Ficha extends ConsumerStatefulWidget {
  const _Ficha({required this.repuesto, required this.onAccion});

  final Repuesto repuesto;
  final ValueChanged<AccionRepuesto> onAccion;

  @override
  ConsumerState<_Ficha> createState() => _FichaState();
}

class _FichaState extends ConsumerState<_Ficha> {
  VentasDeRepuesto? _ventas;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Lo vendido se cuenta al abrir la ficha y no todo el tiempo: hay que
  /// recorrer los trabajos, y eso no tiene por qué pasar en cada pantallazo
  /// de la lista.
  Future<void> _cargar() async {
    final trabajos = await ref.read(trabajosRepoProvider).listar();
    if (!mounted) return;

    setState(() {
      _ventas = ventasDe(trabajos, widget.repuesto.nombre);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.xl,
          0,
          Espacio.xl,
          Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Numeros(
              repuesto: widget.repuesto,
              ventas: _ventas,
              cargando: _cargando,
            ),
            const SizedBox(height: Espacio.xl),
            FilledButton.icon(
              onPressed: () => widget.onAccion(AccionRepuesto.editar),
              icon: const Icon(Icons.edit_rounded, size: 20),
              label: const Text('Editar'),
            ),
            const SizedBox(height: Espacio.md),
            TextButton.icon(
              onPressed: () => widget.onAccion(AccionRepuesto.eliminar),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Eliminar del inventario'),
            ),
          ],
        ),
      );
}

/// Stock, precios, de quién viene y lo que se movió.
class _Numeros extends StatelessWidget {
  const _Numeros({
    required this.repuesto,
    required this.ventas,
    required this.cargando,
  });

  final Repuesto repuesto;
  final VentasDeRepuesto? ventas;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final r = repuesto;
    final v = ventas;
    final gana = r.utilidad;
    final proveedor = r.proveedor.trim();

    return Panel(
      color: Tono.fondo2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Fila(
            'En stock',
            r.agotado ? 'Agotado' : '${r.stock}',
            resaltado: r.agotado,
          ),
          _Fila('Precio de venta', soles(r.precio)),
          _Fila(
            'Precio de compra',
            r.precioCosto > 0 ? soles(r.precioCosto) : 'Sin cargar',
            apagado: r.precioCosto <= 0,
          ),
          if (gana != null)
            _Fila(
              'Deja por unidad',
              '${soles(gana)}'
              '${r.margen == null ? '' : ' (${r.margen!.round()} %)'}',
              enOro: gana >= 0,
              resaltado: gana < 0,
            ),
          if (proveedor.isNotEmpty) _Fila('Se lo compras a', proveedor),
          const Divider(height: Espacio.xl, color: Tono.linea),
          if (cargando)
            Text('Contando lo vendido…', style: Tipo.nota)
          else if (v == null)
            Text('Todavía no se vendió ninguno.', style: Tipo.nota)
          else ...[
            _Fila(
              'Vendidos',
              v.unidades == 1 ? '1 unidad' : '${v.unidades} unidades',
            ),
            _Fila(
              v.completa ? 'Dejaron' : 'Dejaron, como mucho',
              soles(v.ganancia),
              enOro: v.ganancia >= 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(
    this.etiqueta,
    this.valor, {
    this.resaltado = false,
    this.apagado = false,
    this.enOro = false,
  });

  final String etiqueta;
  final String valor;
  final bool resaltado;
  final bool apagado;
  final bool enOro;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Espacio.sm),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: Tipo.secundario)),
            const SizedBox(width: Espacio.md),
            Flexible(
              child: Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Tipo.monto.copyWith(
                  color: resaltado
                      ? Tono.vino
                      : apagado
                          ? Tono.texto3
                          : enOro
                              ? Tono.oroTexto
                              : Tono.texto,
                ),
              ),
            ),
          ],
        ),
      );
}
