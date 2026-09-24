import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/compra.dart';
import '../../../domain/entities/repuesto.dart';
import '../../../domain/services/estadisticas.dart';

/// Lo que se puede hacer con un repuesto desde su ficha.
enum AccionRepuesto { editar, ajustar, comprar, eliminar }

/// La ficha de un repuesto: todo lo que se sabe de él y qué se puede hacer.
///
/// Reemplaza a la fila que llevaba directo a editar. El inventario pasó a ser
/// una lista para **consultar** —buscar y ver stock—, y lo demás vive acá
/// adentro, un toque más lejos. Eliminar también: estaba en la fila, a un
/// toque de distancia de borrar un repuesto sin querer.
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
  List<Compra> _compras = const [];
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
    final id = widget.repuesto.id;
    final compras = id == null
        ? <Compra>[]
        : await ref.read(comprasRepoProvider).deRepuesto(id);

    if (!mounted) return;
    setState(() {
      _ventas = ventasDe(trabajos, widget.repuesto.nombre);
      _compras = compras;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.repuesto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espacio.xl,
        0,
        Espacio.xl,
        Espacio.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Numeros(repuesto: r, ventas: _ventas, cargando: _cargando),
          if (_compras.isNotEmpty) ...[
            const SizedBox(height: Espacio.xl),
            Text('ÚLTIMAS COMPRAS', style: Tipo.etiqueta),
            const SizedBox(height: Espacio.md),
            ListaAgrupada(
              filas: [for (final c in _compras) _FilaCompra(compra: c, repuesto: r)],
            ),
          ],
          const SizedBox(height: Espacio.xl),
          FilledButton.icon(
            onPressed: () => widget.onAccion(AccionRepuesto.comprar),
            icon: const Icon(Icons.local_shipping_rounded, size: 20),
            label: const Text('Registrar compra'),
          ),
          const SizedBox(height: Espacio.md),
          OutlinedButton.icon(
            onPressed: () => widget.onAccion(AccionRepuesto.ajustar),
            icon: const Icon(Icons.numbers_rounded, size: 19),
            label: const Text('Ajustar stock'),
          ),
          const SizedBox(height: Espacio.md),
          OutlinedButton.icon(
            onPressed: () => widget.onAccion(AccionRepuesto.editar),
            icon: const Icon(Icons.edit_rounded, size: 19),
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
}

/// Stock, precios y lo que se movió.
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
              '${soles(gana)}${r.margen == null ? '' : ' (${r.margen!.round()} %)'}',
              enOro: gana >= 0,
              resaltado: gana < 0,
            ),
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
            Text(
              valor,
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
          ],
        ),
      );
}

class _FilaCompra extends StatelessWidget {
  const _FilaCompra({required this.compra, required this.repuesto});

  final Compra compra;
  final Repuesto repuesto;

  @override
  Widget build(BuildContext context) {
    // De toda la compra interesa el renglón de este repuesto.
    final linea = compra.lineas.firstWhere(
      (l) => l.inventarioId == repuesto.id,
      orElse: () => const LineaCompra(desc: '', cantidad: 0, costo: 0),
    );

    final quien = compra.proveedor.trim();

    return FilaLista(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${linea.cantidad} × ${soles(linea.costo)}',
                  style: Tipo.encabezado,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    formatoCorto(compra.fecha),
                    if (quien.isNotEmpty) quien,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tipo.nota,
                ),
              ],
            ),
          ),
          Text(soles(linea.importe), style: Tipo.monto),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- ajuste de stock */

/// Corregir el stock por conteo, sin proveedor ni boleta.
///
/// Es la puerta chica: "conté y hay tres más". La compra es la puerta grande,
/// la que deja rastro de a quién se le compró. Meterlas en el mismo formulario
/// obligaría a inventar un proveedor para arreglar un número.
Future<bool> mostrarAjusteStock(
  BuildContext context,
  WidgetRef ref,
  Repuesto repuesto,
) async {
  final hecho = await mostrarHoja<bool>(
    context,
    titulo: 'Ajustar stock',
    bajada: 'Para cuando contaste y el número no coincide. Si te llegó '
        'mercadería, mejor registra la compra: así queda de quién vino.',
    contenido: (hoja) => _Ajuste(
      repuesto: repuesto,
      onListo: () => Navigator.of(hoja).pop(true),
    ),
  );

  return hecho ?? false;
}

class _Ajuste extends ConsumerStatefulWidget {
  const _Ajuste({required this.repuesto, required this.onListo});

  final Repuesto repuesto;
  final VoidCallback onListo;

  @override
  ConsumerState<_Ajuste> createState() => _AjusteState();
}

class _AjusteState extends ConsumerState<_Ajuste> {
  late final _stock =
      TextEditingController(text: '${widget.repuesto.stock}');
  final _form = GlobalKey<FormState>();
  bool _guardando = false;

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_form.currentState!.validate()) return;

    setState(() => _guardando = true);
    final nuevo = int.tryParse(_stock.text.trim()) ?? widget.repuesto.stock;

    await ref
        .read(inventarioRepoProvider)
        .actualizar(widget.repuesto.copyWith(stock: nuevo));

    if (!mounted) return;
    ref.read(refrescoInventarioProvider.notifier).state++;
    mostrarAviso(context, 'Stock ajustado a $nuevo.');
    widget.onListo();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espacio.xl,
            0,
            Espacio.xl,
            Espacio.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Campo(
                etiqueta: 'Cuántas hay de verdad',
                controlador: _stock,
                autofoco: true,
                teclado: TextInputType.number,
                formateadores: [soloDigitosFormato],
                ayuda: 'Ahora dice ${widget.repuesto.stock}.',
                textoAccion: TextInputAction.done,
                onEnviar: (_) => _guardar(),
                validador: Valida.todos([
                  Valida.obligatorio('el stock'),
                  Valida.entero(),
                ]),
              ),
              const SizedBox(height: Espacio.xl),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: const Text('Guardar el nuevo stock'),
              ),
            ],
          ),
        ),
      );
}
