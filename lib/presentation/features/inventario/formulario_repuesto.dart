import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/codigo_barras.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/texto.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/escaner_codigo.dart';
import '../../../domain/entities/repuesto.dart';
import '../../comunes/barra_accion.dart';

/// Alta y edición de un repuesto.
///
/// Mientras se escribe el nombre, muestra los **similares que ya existen**. Si
/// coincide exacto con uno, no deja crear y ofrece sumarle stock al que ya
/// está: el usuario agregaba "MOTOR", se agotaba, volvía a agregar "MOTOR", y
/// quedaban dos productos —uno agotado para siempre y otro con stock—.
class FormularioRepuesto extends ConsumerStatefulWidget {
  const FormularioRepuesto({super.key, this.repuesto});

  final Repuesto? repuesto;

  @override
  ConsumerState<FormularioRepuesto> createState() => _FormularioRepuestoState();
}

class _FormularioRepuestoState extends ConsumerState<FormularioRepuesto> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _precio = TextEditingController();
  final _costo = TextEditingController();
  final _codigo = TextEditingController();

  List<Repuesto> _inventario = const [];
  bool _guardando = false;

  bool get _esEdicion => widget.repuesto != null;

  @override
  void initState() {
    super.initState();

    final r = widget.repuesto;
    if (r != null) {
      _nombre.text = r.nombre;
      _stock.text = '${r.stock}';
      _precio.text = r.precio > 0 ? r.precio.toStringAsFixed(2) : '';
      _costo.text = r.precioCosto > 0 ? r.precioCosto.toStringAsFixed(2) : '';
      _codigo.text = r.codigoBarras ?? '';
    }

    _cargarInventario();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _stock.dispose();
    _precio.dispose();
    _costo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _cargarInventario() async {
    final items = await ref.read(inventarioRepoProvider).listar();
    if (mounted) setState(() => _inventario = items);
  }

  /// Lo escrito ahora mismo, para calcular la ganancia mientras se teclea.
  /// Se arma un [Repuesto] en vez de repetir la cuenta acá: la regla de qué
  /// se gana vive en un solo lado.
  Repuesto get _borrador => Repuesto(
        nombre: _nombre.text,
        precio: leerNumero(_precio.text),
        precioCosto: leerNumero(_costo.text),
      );

  /// Los que se parecen a lo que se está escribiendo, sin contar el propio.
  List<Repuesto> get _similares {
    final q = _nombre.text.trim();
    if (q.length < 2) return const [];

    return _inventario
        .where((r) =>
            r.id != widget.repuesto?.id &&
            coincide(r.nombre, q) &&
            normalizar(r.nombre) != normalizar(q))
        .take(3)
        .toList();
  }

  /// El que se llama exactamente igual. Si existe, no se puede crear otro.
  Repuesto? get _duplicado {
    final q = normalizar(_nombre.text);
    if (q.isEmpty) return null;

    for (final r in _inventario) {
      if (r.id != widget.repuesto?.id && normalizar(r.nombre) == q) return r;
    }
    return null;
  }

  Future<void> _escanear() async {
    final codigo = await escanearCodigo(context);
    if (codigo != null && mounted) {
      setState(() => _codigo.text = codigo);
      _form.currentState?.validate();
    }
  }

  Future<void> _sumarAlExistente(Repuesto existente) async {
    final cantidad = int.tryParse(_stock.text.trim()) ?? 0;
    if (cantidad <= 0) {
      mostrarAviso(context, 'Pon cuántas unidades entraron.', problema: true);
      return;
    }

    await ref.read(inventarioRepoProvider).sumarStock(existente.id!, cantidad);
    if (!mounted) return;

    mostrarAviso(
      context,
      'Se sumaron $cantidad a "${existente.nombre}". '
      'Ahora hay ${existente.stock + cantidad}.',
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) {
      mostrarAviso(context, 'Revisa los campos marcados.', problema: true);
      return;
    }

    final codigo = _codigo.text.trim();
    final repo = ref.read(inventarioRepoProvider);

    // Un código repetido rompería la búsqueda al vender. Se revisa contra la
    // base y no contra la lista en memoria: pudo entrar otro mientras tanto.
    if (codigo.isNotEmpty &&
        await repo.codigoRepetido(codigo, exceptoId: widget.repuesto?.id)) {
      if (mounted) {
        mostrarAviso(context, 'Ese código ya lo usa otro repuesto.',
            problema: true);
      }
      return;
    }

    setState(() => _guardando = true);

    final repuesto = Repuesto(
      id: widget.repuesto?.id,
      nombre: _nombre.text.trim(),
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      precio: leerNumero(_precio.text),
      precioCosto: leerNumero(_costo.text),
      codigoBarras: codigo.isEmpty ? null : codigo,
    );

    if (_esEdicion) {
      await repo.actualizar(repuesto);
    } else {
      await repo.crear(repuesto);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final duplicado = _duplicado;
    final similares = _similares;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar repuesto' : 'Nuevo repuesto'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
          children: [
            Contenido(
              ancho: Ancho.acciones,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Campo(
                    etiqueta: 'Nombre',
                    controlador: _nombre,
                    ejemplo: 'Ej. Bujía NGK',
                    autofoco: !_esEdicion,
                    textoAccion: TextInputAction.next,
                    validador: Valida.todos([
                      Valida.obligatorio('el nombre'),
                      Valida.minimo(2, 'El nombre'),
                    ]),
                    onCambio: (_) => setState(() {}),
                  ),
                  AnimatedSize(
                    duration: duracion(context, Movimiento.normal),
                    curve: Movimiento.muelle,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (duplicado != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Espacio.md),
                            child: _AvisoDuplicado(
                              existente: duplicado,
                              onSumar: () => _sumarAlExistente(duplicado),
                            ),
                          )
                        else if (similares.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: Espacio.md),
                            child: _Similares(items: similares),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Precio de compra',
                    controlador: _costo,
                    ejemplo: '0.00',
                    opcional: true,
                    ayuda: 'Lo que te cuesta a ti. Es lo que permite saber '
                        'cuánto ganas; no sale impreso en ningún documento.',
                    teclado:
                        const TextInputType.numberWithOptions(decimal: true),
                    formateadores: [decimalFormato],
                    textoAccion: TextInputAction.next,
                    validador: Valida.precio(),
                    onCambio: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Precio de venta',
                    controlador: _precio,
                    ejemplo: '0.00',
                    teclado:
                        const TextInputType.numberWithOptions(decimal: true),
                    formateadores: [decimalFormato],
                    textoAccion: TextInputAction.next,
                    validador: Valida.precio(obligatorio: true),
                    onCambio: (_) => setState(() {}),
                  ),
                  _Ganancia(repuesto: _borrador),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Stock',
                    controlador: _stock,
                    ejemplo: '0',
                    teclado: TextInputType.number,
                    formateadores: [soloDigitosFormato],
                    validador: Valida.entero(),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Código de barras',
                    controlador: _codigo,
                    ejemplo: '7501234567893',
                    opcional: true,
                    teclado: TextInputType.number,
                    ayuda: 'Con código, escanear la etiqueta lo agrega de una.',
                    validador: (valor) => codigoBarrasValido(valor)
                        ? null
                        : 'Ese código no cierra: revisa los dígitos.',
                    onCambio: (_) => setState(() {}),
                    sufijo: IconButton(
                      onPressed: _escanear,
                      tooltip: 'Escanear',
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          size: 22, color: Tono.vino),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BarraAccion(
        texto: _esEdicion ? 'Guardar cambios' : 'Agregar al inventario',
        habilitado: !_guardando && _duplicado == null,
        onTap: _guardar,
      ),
    );
  }
}

class _AvisoDuplicado extends StatelessWidget {
  const _AvisoDuplicado({required this.existente, required this.onSumar});

  final Repuesto existente;
  final VoidCallback onSumar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Espacio.lg),
        decoration: BoxDecoration(
          color: Tono.vinoSuave,
          borderRadius: Redondeo.brChico,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '"${existente.nombre}" ya está en el inventario '
              '(${existente.stock} en stock).',
              style: Tipo.cuerpo.copyWith(
                color: Tono.vino,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Espacio.sm),
            Text(
              'Crear otro igual deja uno agotado para siempre y otro con '
              'stock. Mejor súmale las unidades que entraron.',
              style: Tipo.secundario,
            ),
            const SizedBox(height: Espacio.md),
            OutlinedButton(
              onPressed: onSumar,
              child: const Text('Sumar al que ya está'),
            ),
          ],
        ),
      );
}

/// La ganancia por unidad, calculada mientras se escribe.
///
/// Aparece recién con los dos precios puestos: con uno solo la cuenta diría
/// "pierdes todo", que es ruido mientras se está tecleando.
class _Ganancia extends StatelessWidget {
  const _Ganancia({required this.repuesto});

  final Repuesto repuesto;

  @override
  Widget build(BuildContext context) {
    final gana = repuesto.utilidad;
    if (gana == null || repuesto.precio <= 0) return const SizedBox.shrink();

    final margen = repuesto.margen;
    final pierde = gana < 0;

    return Padding(
      padding: const EdgeInsets.only(top: Espacio.sm),
      child: Text(
        pierde
            ? 'Lo estás vendiendo por debajo de lo que te cuesta: pierdes '
                '${soles(-gana)} por unidad.'
            : 'Ganas ${soles(gana)} por unidad'
                '${margen == null ? '' : ' (${margen.round()} %)'}.',
        style: Tipo.nota.copyWith(
          color: pierde ? Tono.vino : Tono.oroTexto,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Similares extends StatelessWidget {
  const _Similares({required this.items});

  final List<Repuesto> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YA TIENES ALGO PARECIDO', style: Tipo.etiqueta),
          const SizedBox(height: Espacio.sm),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· ${r.nombre} — ${r.stock} en stock · ${soles(r.precio)}',
                style: Tipo.secundario,
              ),
            ),
        ],
      );
}
