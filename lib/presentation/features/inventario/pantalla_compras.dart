import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/compra.dart';
import 'pantalla_compra.dart';

/// Lo que se le compró a los proveedores, de lo más nuevo a lo más viejo.
///
/// Contesta lo que el inventario solo no puede: **qué entró, cuándo y de quién**.
class PantallaCompras extends ConsumerStatefulWidget {
  const PantallaCompras({super.key});

  @override
  ConsumerState<PantallaCompras> createState() => _PantallaComprasState();
}

class _PantallaComprasState extends ConsumerState<PantallaCompras> {
  List<Compra> _compras = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await ref.read(comprasRepoProvider).listar();
    if (mounted) {
      setState(() {
        _compras = lista;
        _cargando = false;
      });
    }
  }

  Future<void> _nueva() async {
    final hecho = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaCompra()),
    );
    if (hecho == true && mounted) await _cargar();
  }

  Future<void> _abrir(Compra compra) async {
    final borrar = await mostrarHoja<bool>(
      context,
      titulo: compra.proveedor.trim().isEmpty
          ? 'Compra del ${formatoCorto(compra.fecha)}'
          : compra.proveedor.trim(),
      bajada: [
        formatoCorto(compra.fecha),
        if (compra.boleta.trim().isNotEmpty) compra.boleta.trim(),
      ].join(' · '),
      contenido: (hoja) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.xl,
          0,
          Espacio.xl,
          Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListaAgrupada(
              filas: [
                for (final l in compra.lineas)
                  FilaLista(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.desc, style: Tipo.encabezado),
                              const SizedBox(height: 3),
                              Text(
                                '${l.cantidad} × ${soles(l.costo)}',
                                style: Tipo.nota,
                              ),
                            ],
                          ),
                        ),
                        Text(soles(l.importe), style: Tipo.monto),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.lg),
            Row(
              children: [
                Expanded(child: Text('TOTAL', style: Tipo.etiqueta)),
                Text(soles(compra.total), style: Tipo.montoGrande),
              ],
            ),
            const SizedBox(height: Espacio.xl),
            TextButton.icon(
              onPressed: () => Navigator.of(hoja).pop(true),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Eliminar esta compra'),
            ),
          ],
        ),
      ),
    );

    if (borrar != true || !mounted) return;
    await _eliminar(compra);
  }

  Future<void> _eliminar(Compra compra) async {
    final seguro = await confirmar(
      context,
      titulo: '¿Eliminar esta compra?',
      mensaje: 'Las ${compra.unidades} unidades que entraron con ella vuelven '
          'a salir del stock. Lo que ya vendiste no cambia.',
      aceptar: 'Eliminar',
      cancelar: 'Permanecer',
      destructivo: true,
    );
    if (!seguro || !mounted) return;

    await ref.read(comprasRepoProvider).eliminar(compra.id!);
    if (!mounted) return;

    ref.read(refrescoInventarioProvider.notifier).state++;
    await _cargar();
    if (mounted) mostrarAviso(context, 'Compra eliminada.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Compras')),
        body: RefreshIndicator(
          color: Tono.vino,
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.only(
              top: Espacio.lg,
              bottom: Espacio.xxl,
            ),
            children: [
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.only(top: Espacio.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_compras.isEmpty)
                Contenido(
                  child: EstadoVacio(
                    icono: Icons.local_shipping_rounded,
                    titulo: 'Todavía no registraste compras',
                    detalle: 'Cuando anotes lo que te llega, vas a saber a '
                        'quién le compraste cada cosa y a cuánto.',
                    accion: FilledButton(
                      onPressed: _nueva,
                      child: const Text('Registrar la primera'),
                    ),
                  ),
                )
              else
                Contenido(
                  child: ListaAgrupada(
                    filas: [
                      for (final c in _compras)
                        _FilaCompra(compra: c, onTap: () => _abrir(c)),
                    ],
                  ),
                ),
              if (_compras.isNotEmpty)
                Contenido(
                  padding: const EdgeInsets.fromLTRB(
                    Espacio.lg,
                    Espacio.xl,
                    Espacio.lg,
                    0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _nueva,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Registrar compra'),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _FilaCompra extends StatelessWidget {
  const _FilaCompra({required this.compra, required this.onTap});

  final Compra compra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quien = compra.proveedor.trim();

    return FilaLista(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quien.isEmpty ? 'Sin proveedor' : quien,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: quien.isEmpty
                      ? Tipo.encabezado.copyWith(color: Tono.texto3)
                      : Tipo.encabezado,
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatoCorto(compra.fecha)} · '
                  '${compra.unidades} ${compra.unidades == 1 ? "unidad" : "unidades"}',
                  style: Tipo.nota,
                ),
              ],
            ),
          ),
          Text(soles(compra.total), style: Tipo.monto),
          const SizedBox(width: Espacio.sm),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Tono.texto3),
        ],
      ),
    );
  }
}
