import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/movimiento.dart';
import '../../core/theme/tipografia.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dinero.dart';
import '../../core/utils/texto.dart';
import '../../core/utils/validacion.dart';
import '../../core/widgets/campo.dart';
import '../../core/widgets/contenido.dart';
import '../../core/widgets/escaner_codigo.dart';
import '../../core/widgets/hoja.dart';
import '../../core/widgets/pulsable.dart';
import '../../domain/entities/linea.dart';
import '../../domain/entities/repuesto.dart';
import '../../domain/repositories/inventario_repository.dart';

/// Agregar repuestos, en un toque.
///
/// Antes esto pedía escribir el nombre, elegirlo de la lista, poner cantidad,
/// poner precio y recién ahí darle a "Agregar": cinco pasos para algo cuyo
/// precio **ya está decidido** en el inventario. Ahora la búsqueda muestra los
/// repuestos y cada uno trae su **+**: un toque lo agrega, otro toque suma una
/// unidad más. La cantidad y el precio siguen ahí para el caso raro, detrás de
/// una pulsación larga, que es donde va lo que casi nunca se usa.
class SelectorRepuesto extends ConsumerStatefulWidget {
  const SelectorRepuesto({
    super.key,
    required this.onAgregar,
    this.autofoco = false,
  });

  /// Recibe las líneas resueltas y, si hubo que dividirlas, el aviso.
  final void Function(List<LineaRepuesto> lineas, String? aviso) onAgregar;

  final bool autofoco;

  @override
  ConsumerState<SelectorRepuesto> createState() => _SelectorRepuestoState();
}

class _SelectorRepuestoState extends ConsumerState<SelectorRepuesto> {
  final _busqueda = TextEditingController();
  final _foco = FocusNode();

  List<Repuesto> _inventario = const [];
  int? _ultimoAgregado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _foco.dispose();
    super.dispose();
  }

  InventarioRepository get _repo => ref.read(inventarioRepoProvider);

  Future<void> _cargar() async {
    final items = await _repo.listar();
    if (mounted) setState(() => _inventario = items);
  }

  List<Repuesto> get _resultados {
    final q = _busqueda.text.trim();
    final encontrados = _inventario.where((r) => coincide(r.nombre, q)).toList();
    // Con el campo vacío se muestran los primeros: abrir el paso y ver ya la
    // lista ahorra escribir cuando el taller tiene veinte repuestos y no dos
    // mil.
    return q.isEmpty ? encontrados.take(6).toList() : encontrados;
  }

  bool get _hayNombreExacto {
    final q = normalizar(_busqueda.text);
    return q.isNotEmpty && _inventario.any((r) => normalizar(r.nombre) == q);
  }

  /// El camino rápido: una unidad, al precio que ya tiene puesto.
  Future<void> _agregarUno(Repuesto item) async {
    HapticFeedback.selectionClick();
    setState(() => _ultimoAgregado = item.id);

    final resultado = await _repo.agregarRepuesto(
      inventarioId: item.id,
      desc: item.nombre,
      cant: 1,
      precio: item.precio,
    );

    widget.onAgregar(resultado.lineas, resultado.aviso);
    await _cargar();

    if (mounted) {
      await Future.delayed(Movimiento.normal);
      if (mounted) setState(() => _ultimoAgregado = null);
    }
  }

  /// El camino raro: otra cantidad u otro precio. Detrás de una pulsación
  /// larga, no ocupando la pantalla todo el tiempo.
  Future<void> _agregarConDetalle(Repuesto? item, {String? nombreLibre}) async {
    final datos = await mostrarHoja<_DetalleLinea>(
      context,
      titulo: item?.nombre ?? nombreLibre ?? 'Repuesto',
      bajada: item == null
          ? 'No está en el inventario: se agrega como repuesto externo.'
          : item.agotado
              ? 'Agotado. Lo que falte se registra como externo.'
              : '${item.stock} en stock · ${soles(item.precio)}',
      contenido: (hoja) => _FormularioDetalle(
        precioSugerido: item?.precio ?? 0,
        exigePrecio: item == null,
        onListo: (detalle) => Navigator.of(hoja).pop(detalle),
      ),
    );

    if (datos == null || !mounted) return;

    final resultado = await _repo.agregarRepuesto(
      inventarioId: item?.id,
      desc: item?.nombre ?? (nombreLibre ?? '').trim(),
      cant: datos.cantidad,
      precio: datos.precio,
    );

    widget.onAgregar(resultado.lineas, resultado.aviso);
    _busqueda.clear();
    await _cargar();
  }

  /// Un escaneo agrega la línea de una: apuntar y listo es todo el punto de
  /// tener un lector.
  Future<void> _escanear() async {
    final codigo = await escanearCodigo(context, titulo: 'Escanear repuesto');
    if (codigo == null || !mounted) return;

    final item = await _repo.buscarPorCodigo(codigo);

    if (item == null) {
      // No se inventa una línea con el número de barras: eso no le dice nada
      // a un cliente en una boleta. Se avisa y se deja listo para buscarlo.
      widget.onAgregar(
        const [],
        'Ningún repuesto tiene el código $codigo. Agrégalo al inventario '
        'primero.',
      );
      if (mounted) _foco.requestFocus();
      return;
    }

    await _agregarUno(item);
  }

  @override
  Widget build(BuildContext context) {
    // Que otro pedazo de la app toque el inventario tiene que reflejarse acá.
    ref.listen(refrescoInventarioProvider, (_, _) => _cargar());

    final resultados = _resultados;
    final escrito = _busqueda.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busqueda,
          focusNode: _foco,
          autofocus: widget.autofoco,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          style: Tipo.cuerpo,
          decoration: InputDecoration(
            hintText: 'Buscar repuesto',
            prefixIcon:
                const Icon(Icons.search_rounded, size: 21, color: Tono.texto3),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (escrito.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpiar',
                    onPressed: () {
                      _busqueda.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded,
                        size: 19, color: Tono.texto3),
                  ),
                IconButton(
                  tooltip: 'Escanear código de barras',
                  onPressed: _escanear,
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      size: 22, color: Tono.vino),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espacio.md),
        if (resultados.isEmpty && escrito.isEmpty)
          Text(
            'El inventario está vacío. Puedes cargar repuestos igual, '
            'escribiendo el nombre aquí.',
            style: Tipo.secundario,
          ),
        if (resultados.isNotEmpty)
          ListaAgrupada(
            filas: [
              for (final item in resultados)
                _FilaRepuesto(
                  item: item,
                  destacado: _ultimoAgregado == item.id,
                  onAgregar: () => _agregarUno(item),
                  onDetalle: () => _agregarConDetalle(item),
                ),
            ],
          ),
        // Lo que se escribió y no está en el inventario: se puede cargar igual
        // como externo, con su precio, sin salir de acá.
        if (escrito.isNotEmpty && !_hayNombreExacto) ...[
          const SizedBox(height: Espacio.md),
          Panel(
            color: Tono.oroSuave,
            padding: const EdgeInsets.symmetric(
              horizontal: Espacio.lg,
              vertical: Espacio.md,
            ),
            onTap: () => _agregarConDetalle(null, nombreLibre: escrito),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: Tono.oro, size: 21),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: Text(
                    'Agregar "$escrito" como repuesto externo',
                    style: Tipo.cuerpo.copyWith(
                      color: Tono.oroTexto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Una fila del buscador: el nombre, lo que hay, y el **+**.
class _FilaRepuesto extends StatelessWidget {
  const _FilaRepuesto({
    required this.item,
    required this.onAgregar,
    required this.onDetalle,
    this.destacado = false,
  });

  final Repuesto item;
  final VoidCallback onAgregar;
  final VoidCallback onDetalle;

  /// Se enciende un instante después de agregar: la confirmación de que el
  /// toque entró, sin un cartel que tape la pantalla.
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duracion(context, Movimiento.normal),
      curve: Movimiento.salida,
      color: destacado ? Tono.oroSuave : Colors.transparent,
      child: FilaLista(
        onTap: onAgregar,
        onLongPress: onDetalle,
        padding: const EdgeInsets.fromLTRB(
          Espacio.lg,
          Espacio.md,
          Espacio.md,
          Espacio.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.encabezado,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        soles(item.precio),
                        style: Tipo.montoChico.copyWith(
                          color: Tono.vinoTexto,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: Espacio.sm),
                      Insignia(
                        item.agotado ? 'Agotado' : '${item.stock} en stock',
                        color: item.agotado ? Tono.vino : Tono.texto2,
                        fondo: item.agotado ? Tono.vinoSuave : Tono.fondo2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espacio.md),
            Pulsable(
              onTap: onAgregar,
              escala: 0.86,
              semantica: 'Agregar ${item.nombre}',
              child: Container(
                width: kAreaTactil,
                height: kAreaTactil,
                decoration: const BoxDecoration(
                  color: Tono.vino,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cantidad y precio de una línea, para el caso que se sale de lo normal.
class _DetalleLinea {
  const _DetalleLinea(this.cantidad, this.precio);

  final int cantidad;
  final double precio;
}

class _FormularioDetalle extends StatefulWidget {
  const _FormularioDetalle({
    required this.precioSugerido,
    required this.exigePrecio,
    required this.onListo,
  });

  final double precioSugerido;

  /// Un repuesto externo no tiene precio en ningún lado: si no se pone acá,
  /// la línea entra en cero y el total sale mal sin que nadie lo note.
  final bool exigePrecio;

  final ValueChanged<_DetalleLinea> onListo;

  @override
  State<_FormularioDetalle> createState() => _FormularioDetalleState();
}

class _FormularioDetalleState extends State<_FormularioDetalle> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _precio = TextEditingController(
    text: widget.precioSugerido > 0
        ? widget.precioSugerido.toStringAsFixed(2)
        : '',
  );
  int _cantidad = 1;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_form.currentState!.validate()) return;
    widget.onListo(_DetalleLinea(_cantidad, leerNumero(_precio.text)));
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
              Text('CANTIDAD', style: Tipo.etiqueta),
              const SizedBox(height: Espacio.md),
              Row(
                children: [
                  _Paso(
                    icono: Icons.remove_rounded,
                    onTap: () => setState(
                      () => _cantidad = _cantidad > 1 ? _cantidad - 1 : 1,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$_cantidad',
                      textAlign: TextAlign.center,
                      style: Tipo.display.copyWith(fontSize: 30),
                    ),
                  ),
                  _Paso(
                    icono: Icons.add_rounded,
                    onTap: () => setState(() => _cantidad++),
                  ),
                ],
              ),
              const SizedBox(height: Espacio.xl),
              Campo(
                etiqueta: 'Precio unitario',
                controlador: _precio,
                ejemplo: '0.00',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formateadores: [decimalFormato],
                validador: Valida.precio(obligatorio: widget.exigePrecio),
              ),
              const SizedBox(height: Espacio.xl),
              FilledButton(onPressed: _confirmar, child: const Text('Agregar')),
            ],
          ),
        ),
      );
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.88,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Tono.fondo2,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 22, color: Tono.texto),
        ),
      );
}
