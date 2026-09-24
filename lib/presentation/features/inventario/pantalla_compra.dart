import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/texto.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/compra.dart';
import '../../../domain/entities/repuesto.dart';
import '../../comunes/barra_accion.dart';
import '../../comunes/campo_fecha.dart';
import 'formulario_repuesto.dart';

/// Registrar una compra: lo que entró al taller y de dónde vino.
///
/// Es la puerta por la que sube el stock cuando importa dejar rastro —a quién
/// se le compró, cuándo y a cuánto—. La otra puerta, "Ajustar stock", existe
/// para el recuento a ojo, que no es una compra y no merece este formulario.
///
/// Proveedor y boleta son opcionales: media compra de taller es en efectivo y
/// sin papel, y exigirlos lograría que no se registre nada.
class PantallaCompra extends ConsumerStatefulWidget {
  const PantallaCompra({super.key, this.inicial});

  /// Con qué repuesto arranca, cuando se entra desde su ficha.
  final Repuesto? inicial;

  @override
  ConsumerState<PantallaCompra> createState() => _PantallaCompraState();
}

class _PantallaCompraState extends ConsumerState<PantallaCompra> {
  final _proveedor = TextEditingController();
  final _boleta = TextEditingController();

  String _fecha = hoyISO();
  final List<LineaCompra> _lineas = [];
  List<String> _frecuentes = const [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final item = widget.inicial;
    if (item != null) {
      _lineas.add(LineaCompra(
        desc: item.nombre,
        cantidad: 1,
        costo: item.precioCosto,
        inventarioId: item.id,
      ));
    }

    _cargarFrecuentes();
  }

  @override
  void dispose() {
    _proveedor.dispose();
    _boleta.dispose();
    super.dispose();
  }

  Future<void> _cargarFrecuentes() async {
    final lista = await ref.read(comprasRepoProvider).proveedoresFrecuentes();
    if (mounted) setState(() => _frecuentes = lista);
  }

  double get _total =>
      redondear(_lineas.fold<double>(0, (suma, l) => suma + l.importe));

  /* ------------------------------------------------------------ renglones */

  Future<void> _agregar() async {
    final linea = await mostrarHoja<LineaCompra>(
      context,
      titulo: 'Qué entró',
      bajada: 'Elige el repuesto y pon cuántas unidades y a cuánto.',
      contenido: (hoja) => _ElegirYContar(
        onListo: (linea) => Navigator.of(hoja).pop(linea),
      ),
    );

    if (linea == null || !mounted) return;

    setState(() {
      // Dos renglones del mismo repuesto al mismo precio se suman: en el
      // papel, "10 × BUJIA" se lee mejor que dos veces "5 × BUJIA".
      final i = _lineas.indexWhere((l) =>
          l.inventarioId == linea.inventarioId && l.costo == linea.costo);

      if (i >= 0) {
        _lineas[i] =
            _lineas[i].copyWith(cantidad: _lineas[i].cantidad + linea.cantidad);
      } else {
        _lineas.add(linea);
      }
    });
  }

  /* ------------------------------------------------------------- guardado */

  Future<void> _guardar() async {
    if (_guardando) return;

    if (_lineas.isEmpty) {
      mostrarAviso(context, 'Agrega al menos un repuesto.', problema: true);
      return;
    }

    setState(() => _guardando = true);

    try {
      await ref.read(comprasRepoProvider).registrar(Compra(
            fecha: _fecha,
            proveedor: _proveedor.text.trim(),
            boleta: _boleta.text.trim(),
            lineas: _lineas,
          ));

      if (!mounted) return;
      ref.read(refrescoInventarioProvider.notifier).state++;

      final unidades = _lineas.fold<int>(0, (s, l) => s + l.cantidad);
      mostrarAviso(
        context,
        unidades == 1
            ? 'Compra registrada: entró 1 unidad.'
            : 'Compra registrada: entraron $unidades unidades.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        mostrarAviso(context, 'No se pudo guardar la compra: $e',
            problema: true);
      }
    }
  }

  /* --------------------------------------------------------------- vista */

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Registrar compra')),
        body: ListView(
          padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
          children: [
            Contenido(
              ancho: Ancho.acciones,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CampoFecha(
                    fecha: _fecha,
                    etiqueta: 'Fecha de la compra',
                    onCambio: (f) => setState(() => _fecha = f),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Proveedor',
                    controlador: _proveedor,
                    ejemplo: 'A quién se lo compraste',
                    opcional: true,
                    textoAccion: TextInputAction.next,
                    onCambio: (_) => setState(() {}),
                  ),
                  if (_frecuentes.isNotEmpty) ...[
                    const SizedBox(height: Espacio.sm),
                    _Frecuentes(
                      nombres: _frecuentes,
                      onElegir: (nombre) => setState(() {
                        _proveedor.text = nombre;
                      }),
                    ),
                  ],
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Boleta o factura',
                    controlador: _boleta,
                    ejemplo: 'B001-1234',
                    opcional: true,
                    textoAccion: TextInputAction.done,
                  ),
                  const SizedBox(height: Espacio.xl),
                  Text('QUÉ ENTRÓ', style: Tipo.etiqueta),
                  const SizedBox(height: Espacio.md),
                  if (_lineas.isEmpty)
                    Panel(
                      color: Tono.fondo2,
                      child: Text(
                        'Todavía no agregaste nada. El stock sube con lo que '
                        'pongas acá.',
                        style: Tipo.secundario,
                      ),
                    )
                  else
                    ListaAgrupada(
                      filas: [
                        for (var i = 0; i < _lineas.length; i++)
                          _FilaLinea(
                            linea: _lineas[i],
                            onQuitar: () => setState(() => _lineas.removeAt(i)),
                          ),
                      ],
                    ),
                  const SizedBox(height: Espacio.md),
                  OutlinedButton.icon(
                    onPressed: _agregar,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Agregar repuesto'),
                  ),
                  if (_lineas.isNotEmpty) ...[
                    const SizedBox(height: Espacio.xl),
                    Row(
                      children: [
                        Expanded(child: Text('TOTAL', style: Tipo.etiqueta)),
                        Text(soles(_total), style: Tipo.montoGrande),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BarraAccion(
          texto: 'Guardar compra',
          habilitado: !_guardando && _lineas.isNotEmpty,
          onTap: _guardar,
        ),
      );
}

/// Los proveedores a los que más se les compra, para no volver a escribirlos.
///
/// Es el punto medio entre un campo libre y un catálogo que hay que mantener:
/// la lista se arma sola con lo que ya se compró.
class _Frecuentes extends StatelessWidget {
  const _Frecuentes({required this.nombres, required this.onElegir});

  final List<String> nombres;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: Espacio.sm,
        runSpacing: Espacio.sm,
        children: [
          for (final nombre in nombres)
            GestureDetector(
              onTap: () => onElegir(nombre),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espacio.md,
                  vertical: Espacio.sm,
                ),
                decoration: BoxDecoration(
                  color: Tono.fondo,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Tono.linea),
                ),
                child: Text(
                  nombre,
                  style: Tipo.nota.copyWith(
                    color: Tono.texto2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _FilaLinea extends StatelessWidget {
  const _FilaLinea({required this.linea, required this.onQuitar});

  final LineaCompra linea;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) => FilaLista(
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
                  Text(linea.desc, style: Tipo.encabezado),
                  const SizedBox(height: 3),
                  Text(
                    '${linea.cantidad} × ${soles(linea.costo)}',
                    style: Tipo.nota,
                  ),
                ],
              ),
            ),
            Text(soles(linea.importe), style: Tipo.monto),
            IconButton(
              onPressed: onQuitar,
              iconSize: 19,
              visualDensity: VisualDensity.compact,
              color: Tono.texto3,
              tooltip: 'Quitar',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
}

/// Elegir el repuesto y decir cuántas unidades entraron y a cuánto.
///
/// Dos pasos en la misma hoja: primero cuál, después cuánto. Separarlos en dos
/// ventanas obligaría a volver atrás cada vez que se erró el repuesto.
class _ElegirYContar extends ConsumerStatefulWidget {
  const _ElegirYContar({required this.onListo});

  final ValueChanged<LineaCompra> onListo;

  @override
  ConsumerState<_ElegirYContar> createState() => _ElegirYContarState();
}

class _ElegirYContarState extends ConsumerState<_ElegirYContar> {
  final _busqueda = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  final _costo = TextEditingController();
  final _form = GlobalKey<FormState>();

  List<Repuesto> _inventario = const [];
  Repuesto? _elegido;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _cantidad.dispose();
    _costo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final items = await ref.read(inventarioRepoProvider).listar();
    if (mounted) setState(() => _inventario = items);
  }

  List<Repuesto> get _resultados {
    final q = _busqueda.text.trim();
    final encontrados =
        _inventario.where((r) => coincide(r.nombre, q)).toList();
    return q.isEmpty ? encontrados.take(6).toList() : encontrados;
  }

  void _elegir(Repuesto item) {
    setState(() {
      _elegido = item;
      _costo.text =
          item.precioCosto > 0 ? item.precioCosto.toStringAsFixed(2) : '';
    });
  }

  /// Lo que se compró y todavía no está en el inventario se crea acá mismo:
  /// mandar a otra pantalla y volver a empezar la compra sería peor.
  Future<void> _crearRepuesto() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FormularioRepuesto()),
    );
    if (creado != true || !mounted) return;

    await _cargar();
    if (!mounted) return;

    // Se busca por el nombre tecleado: es el que la persona acaba de crear.
    final nuevo = await ref
        .read(inventarioRepoProvider)
        .porNombreExacto(_busqueda.text.trim());
    if (nuevo != null && mounted) _elegir(nuevo);
  }

  void _confirmar() {
    final item = _elegido;
    if (item == null) return;
    if (!_form.currentState!.validate()) return;

    widget.onListo(LineaCompra(
      desc: item.nombre,
      cantidad: int.tryParse(_cantidad.text.trim()) ?? 1,
      costo: leerNumero(_costo.text),
      inventarioId: item.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = _elegido;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espacio.xl,
        0,
        Espacio.xl,
        Espacio.xl,
      ),
      child: item == null ? _buscador() : _contador(item),
    );
  }

  Widget _buscador() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _busqueda,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: Tipo.cuerpo,
            decoration: const InputDecoration(
              hintText: 'Buscar repuesto',
              prefixIcon:
                  Icon(Icons.search_rounded, size: 21, color: Tono.texto3),
            ),
          ),
          const SizedBox(height: Espacio.md),
          if (_resultados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Espacio.lg),
              child: Text(
                _inventario.isEmpty
                    ? 'El inventario está vacío. Crea el repuesto y después '
                        'registra lo que entró.'
                    : 'Ninguno coincide. Si es nuevo, créalo.',
                style: Tipo.secundario,
              ),
            )
          else
            ListaAgrupada(
              filas: [
                for (final r in _resultados)
                  FilaLista(
                    onTap: () => _elegir(r),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.nombre, style: Tipo.encabezado),
                              const SizedBox(height: 3),
                              Text('${r.stock} en stock', style: Tipo.nota),
                            ],
                          ),
                        ),
                        if (r.precioCosto > 0)
                          Text(soles(r.precioCosto), style: Tipo.monto),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Espacio.md),
          OutlinedButton.icon(
            onPressed: _crearRepuesto,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Crear repuesto nuevo'),
          ),
        ],
      );

  Widget _contador(Repuesto item) => Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.nombre, style: Tipo.titulo2)),
                TextButton(
                  onPressed: () => setState(() => _elegido = null),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            const SizedBox(height: Espacio.lg),
            Campo(
              etiqueta: 'Cuántas entraron',
              controlador: _cantidad,
              teclado: TextInputType.number,
              formateadores: [soloDigitosFormato],
              autofoco: true,
              textoAccion: TextInputAction.next,
              validador: Valida.todos([
                Valida.obligatorio('la cantidad'),
                Valida.entero(),
              ]),
            ),
            const SizedBox(height: Espacio.lg),
            Campo(
              etiqueta: 'Precio de compra por unidad',
              controlador: _costo,
              ejemplo: '0.00',
              ayuda: 'Queda como el precio de compra del repuesto.',
              teclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [decimalFormato],
              textoAccion: TextInputAction.done,
              onEnviar: (_) => _confirmar(),
              validador: Valida.precio(obligatorio: true),
            ),
            const SizedBox(height: Espacio.xl),
            FilledButton(
              onPressed: _confirmar,
              child: const Text('Agregar a la compra'),
            ),
          ],
        ),
      );
}
