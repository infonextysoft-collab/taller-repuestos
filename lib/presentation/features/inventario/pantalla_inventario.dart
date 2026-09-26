import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../shell/barra_inferior.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/texto.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/escaner_codigo.dart';
import '../../../domain/entities/repuesto.dart';
import '../../comunes/filtro_chips.dart';
import 'formulario_repuesto.dart';
import 'hoja_repuesto.dart';

enum _FiltroStock { todos, conStock, agotados }

/// Los repuestos en stock.
class PantallaInventario extends ConsumerStatefulWidget {
  const PantallaInventario({super.key});

  @override
  ConsumerState<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends ConsumerState<PantallaInventario> {
  final _busqueda = TextEditingController();

  List<Repuesto> _items = const [];
  _FiltroStock _filtro = _FiltroStock.todos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final items = await ref.read(inventarioRepoProvider).listar();
    if (mounted) {
      setState(() {
        _items = items;
        _cargando = false;
      });
    }
  }

  List<Repuesto> get _visibles => _items.where((r) {
        if (!coincide(r.nombre, _busqueda.text)) return false;
        return switch (_filtro) {
          _FiltroStock.todos => true,
          _FiltroStock.conStock => !r.agotado,
          _FiltroStock.agotados => r.agotado,
        };
      }).toList();

  int get _agotados => _items.where((r) => r.agotado).length;

  Future<void> _abrirFormulario([Repuesto? repuesto]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormularioRepuesto(repuesto: repuesto)),
    );

    if (guardado == true && mounted) {
      ref.read(refrescoInventarioProvider.notifier).state++;
      await _cargar();
    }
  }

  /// Tocar una fila abre su ficha, y de ahí sale todo lo demás. La lista
  /// quedó para **consultar**: buscar y ver stock.
  Future<void> _abrirFicha(Repuesto r) async {
    final accion = await mostrarFichaRepuesto(context, r);
    if (accion == null || !mounted) return;

    switch (accion) {
      case AccionRepuesto.editar:
        await _abrirFormulario(r);

      case AccionRepuesto.eliminar:
        await _eliminar(r);
    }
  }

  Future<void> _buscarPorCodigo() async {
    final codigo = await escanearCodigo(context, titulo: 'Buscar por código');
    if (codigo == null || !mounted) return;

    final item = await ref.read(inventarioRepoProvider).buscarPorCodigo(codigo);
    if (!mounted) return;

    if (item == null) {
      mostrarAviso(context, 'Ningún repuesto tiene el código $codigo.');
      return;
    }
    await _abrirFicha(item);
  }

  Future<void> _eliminar(Repuesto r) async {
    final seguro = await confirmar(
      context,
      titulo: '¿Eliminar ${r.nombre}?',
      mensaje: 'Sale del inventario. Los trabajos que ya lo tenían cargado no '
          'cambian.',
      aceptar: 'Eliminar',
      cancelar: 'Permanecer',
      destructivo: true,
    );
    if (!seguro) return;

    await ref.read(inventarioRepoProvider).eliminar(r.id!);
    if (!mounted) return;

    ref.read(refrescoInventarioProvider.notifier).state++;
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoInventarioProvider, (_, _) => _cargar());

    // Llegar desde la tarjeta de "sin stock" tiene que dejar el filtro puesto:
    // mandar a la pestaña y hacer buscar de nuevo lo agotado sería devolver el
    // trabajo que la tarjeta ya hizo.
    ref.listen(pedidoAgotadosProvider, (_, _) {
      setState(() => _filtro = _FiltroStock.agotados);
    });

    final visibles = _visibles;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: Tono.vino,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kAltoBarra + Espacio.xl),
          children: [
            Contenido(
              padding: const EdgeInsets.fromLTRB(
                Espacio.lg,
                Espacio.lg,
                Espacio.lg,
                Espacio.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busqueda,
                          onChanged: (_) => setState(() {}),
                          style: Tipo.cuerpo,
                          decoration: const InputDecoration(
                            hintText: 'Buscar repuesto',
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 21, color: Tono.texto3),
                          ),
                        ),
                      ),
                      const SizedBox(width: Espacio.md),
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _buscarPorCodigo,
                          style:
                              OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Icon(Icons.qr_code_scanner_rounded,
                              size: 22, color: Tono.vino),
                        ),
                      ),
                    ],
                  ),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: Espacio.md),
                    Row(
                      children: [
                        Expanded(
                          child: FiltroChips<_FiltroStock>(
                            compactos: true,
                            valor: _filtro,
                            opciones: [
                              OpcionChip(
                                  _FiltroStock.todos, 'Todos', _items.length),
                              OpcionChip(_FiltroStock.conStock, 'Con stock',
                                  _items.length - _agotados),
                              OpcionChip(_FiltroStock.agotados, 'Agotados',
                                  _agotados),
                            ],
                            onCambio: (f) => setState(() => _filtro = f),
                          ),
                        ),
                        const SizedBox(width: Espacio.sm),
                        // Arriba y siempre a mano: con cien repuestos, el
                        // botón del final de la lista queda a cien filas.
                        // Va en blanco con el ícono en vino, igual que el
                        // escáner de arriba, para no confundirse con el "+"
                        // grande de la barra, que carga un trabajo.
                        SizedBox(
                          width: kAreaTactil,
                          height: kAreaTactil,
                          child: Tooltip(
                            message: 'Nuevo repuesto',
                            child: OutlinedButton(
                              onPressed: _abrirFormulario,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size.square(kAreaTactil),
                                foregroundColor: Tono.vino,
                                shape: const CircleBorder(),
                              ),
                              child: const Icon(Icons.add_rounded, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: Espacio.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibles.isEmpty)
              Contenido(
                child: EstadoVacio(
                  icono: Icons.inventory_2_rounded,
                  titulo: _items.isEmpty
                      ? 'El inventario está vacío'
                      : 'Ningún repuesto coincide',
                  detalle: _items.isEmpty
                      ? 'Carga lo que tienes con su precio: después, vender es '
                          'buscarlo y tocar el +.'
                      : 'Prueba con otro nombre o cambia el filtro.',
                  accion: _items.isEmpty
                      ? FilledButton(
                          onPressed: _abrirFormulario,
                          child: const Text('Agregar el primero'),
                        )
                      : null,
                ),
              )
            else
              Contenido(
                child: ListaAgrupada(
                  filas: [
                    for (final r in visibles)
                      _FilaRepuesto(repuesto: r, onTap: () => _abrirFicha(r)),
                  ],
                ),
              ),
            // El alta va dentro del scroll y no en un botón flotante: la barra
            // de navegación ahora flota, y dos cosas flotando en la misma
            // esquina se tapan entre sí.
            Contenido(
              padding: const EdgeInsets.fromLTRB(
                Espacio.lg,
                Espacio.xl,
                Espacio.lg,
                0,
              ),
              child: OutlinedButton.icon(
                onPressed: _abrirFormulario,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Nuevo repuesto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaRepuesto extends StatelessWidget {
  const _FilaRepuesto({required this.repuesto, required this.onTap});

  final Repuesto repuesto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = repuesto;

    return FilaLista(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        Espacio.md,
        Espacio.sm,
        Espacio.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nombre, style: Tipo.encabezado),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Insignia(
                      r.agotado ? 'Agotado' : '${r.stock} en stock',
                      color: r.agotado ? Tono.vino : Tono.oroTexto,
                      fondo: r.agotado ? Tono.vinoSuave : Tono.oroSuave,
                    ),
                    if (r.codigoBarras != null) ...[
                      const SizedBox(width: Espacio.sm),
                      const Icon(Icons.qr_code_rounded,
                          size: 14, color: Tono.texto3),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(soles(r.precio), style: Tipo.monto),
          const SizedBox(width: Espacio.sm),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Tono.texto3),
        ],
      ),
    );
  }
}
