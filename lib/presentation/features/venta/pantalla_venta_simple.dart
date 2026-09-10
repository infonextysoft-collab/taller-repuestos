import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/campo_documento.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/resumen_totales.dart';
import '../../../core/widgets/tabla_items.dart';
import '../../../domain/entities/trabajo.dart';
import '../../comunes/barra_accion.dart';
import '../../comunes/controlador_registro.dart';
import '../../comunes/campo_fecha.dart';
import '../../comunes/selector_repuesto.dart';
import '../documento/pantalla_documento.dart';

/// Venta simple: vendió una pieza, no hizo ningún trabajo.
///
/// Una sola pantalla, sin pasos. Sirve para crear y para editar, siempre sobre
/// el mismo registro.
class PantallaVentaSimple extends ConsumerStatefulWidget {
  const PantallaVentaSimple({super.key, this.id});

  /// `null` = venta nueva.
  final int? id;

  @override
  ConsumerState<PantallaVentaSimple> createState() =>
      _PantallaVentaSimpleState();
}

class _PantallaVentaSimpleState extends ConsumerState<PantallaVentaSimple> {
  late final ControladorRegistro _ctrl = ControladorRegistro(
    ref.read(trabajosRepoProvider),
    ref.read(inventarioRepoProvider),
    ref.read(recordatoriosRepoProvider),
  );

  final _form = GlobalKey<FormState>();
  final _cliente = TextEditingController();
  final _ruc = TextEditingController();
  final _descuento = TextEditingController();

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_alCambiar);
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (widget.id == null) {
      _ctrl.empezar(TipoTrabajo.venta);
    } else {
      await _ctrl.cargar(widget.id!);
      final r = _ctrl.registro;
      _cliente.text = r.cliente;
      _ruc.text = r.ruc;
      if (r.descuento > 0) _descuento.text = r.descuento.toStringAsFixed(2);
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_alCambiar);
    _ctrl.dispose();
    _cliente.dispose();
    _ruc.dispose();
    _descuento.dispose();
    super.dispose();
  }

  Future<bool> _alSalir() async {
    if (!_ctrl.hayCambios) return true;

    final salir = await confirmar(
      context,
      titulo: '¿Descartar la venta?',
      mensaje: 'Los repuestos que agregaste vuelven al inventario.',
      aceptar: 'Descartar',
      cancelar: 'Permanecer',
      destructivo: true,
    );

    if (salir) await _ctrl.descartar();
    return salir;
  }

  /// Revisa **todo** antes de guardar, no solo lo que la persona tocó: un
  /// campo que nunca se abrió también puede estar vacío.
  Future<void> _guardar({required bool terminar}) async {
    if (!_form.currentState!.validate()) {
      mostrarAviso(context, 'Revisa los campos marcados.', problema: true);
      return;
    }

    if (_ctrl.registro.repuestos.isEmpty) {
      mostrarAviso(
        context,
        'Agrega al menos un repuesto: una venta sin líneas no tiene qué '
        'cobrar.',
        problema: true,
      );
      return;
    }

    final registro = terminar ? await _ctrl.terminar() : await _ctrl.guardar();

    if (!mounted) return;
    ref.read(refrescoHistorialProvider.notifier).state++;
    ref.read(refrescoInventarioProvider.notifier).state++;

    if (!terminar) {
      mostrarAviso(context, 'Guardado como pendiente.');
      return;
    }

    // Terminar lleva derecho al documento: es lo que se hace después.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PantallaDocumento(id: registro.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _ctrl.totales;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        final salir = await _alSalir();
        if (!context.mounted) return;
        if (salir) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'Venta de repuestos' : 'Editar venta'),
          actions: [
            if (!_cargando)
              Padding(
                padding: const EdgeInsets.only(right: Espacio.sm),
                child: TextButton(
                  onPressed:
                      _ctrl.guardando ? null : () => _guardar(terminar: false),
                  child: const Text('Guardar'),
                ),
              ),
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.only(
                    top: Espacio.lg,
                    bottom: Espacio.xxxl,
                  ),
                  children: [
                    Contenido(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Seccion(
                            titulo: 'Cliente',
                            child: Column(
                              children: [
                                Campo(
                                  etiqueta: 'Nombre',
                                  controlador: _cliente,
                                  ejemplo: 'A quién le vendiste',
                                  textoAccion: TextInputAction.next,
                                  validador: Valida.obligatorio(
                                      'el nombre del cliente'),
                                  onCambio: (v) => _ctrl.editar(
                                    (r) => r.copyWith(cliente: v, facturarA: v),
                                  ),
                                ),
                                const SizedBox(height: Espacio.lg),
                                CampoDocumento(
                                  controlador: _ruc,
                                  onCambio: (v) =>
                                      _ctrl.editar((r) => r.copyWith(ruc: v)),
                                ),
                                const SizedBox(height: Espacio.lg),
                                CampoFecha(
                                  fecha: _ctrl.registro.fecha,
                                  onCambio: (f) =>
                                      _ctrl.editar((r) => r.copyWith(fecha: f)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Espacio.xxl),
                          Seccion(
                            titulo: 'Repuestos',
                            child: SelectorRepuesto(
                              onAgregar: (lineas, aviso) {
                                _ctrl.agregarRepuestos(lineas);
                                if (aviso != null) mostrarAviso(context, aviso);
                              },
                            ),
                          ),
                          const SizedBox(height: Espacio.lg),
                          TablaItems(
                            items: _ctrl.registro.repuestos,
                            mostrarOrigen: true,
                            vacio: 'Todavía no agregaste ningún repuesto.',
                            onEliminar: _ctrl.quitarRepuesto,
                            onCambiarCantidad: (i, delta) async {
                              final aviso =
                                  await _ctrl.cambiarCantidad(i, delta);
                              if (!context.mounted || aviso == null) return;
                              mostrarAviso(context, aviso);
                            },
                          ),
                          const SizedBox(height: Espacio.xxl),
                          Seccion(
                            titulo: 'Cierre',
                            child: Campo(
                              etiqueta: 'Descuento',
                              controlador: _descuento,
                              ejemplo: '0.00',
                              opcional: true,
                              teclado: const TextInputType.numberWithOptions(
                                  decimal: true),
                              formateadores: [decimalFormato],
                              ayuda: 'Se resta del total, antes del IGV.',
                              validador: Valida.descuento(
                                () => _ctrl.totales.subtotal,
                              ),
                              onCambio: (v) => _ctrl.editar(
                                (r) => r.copyWith(descuento: leerNumero(v)),
                              ),
                            ),
                          ),
                          const SizedBox(height: Espacio.lg),
                          ResumenTotales(totales: t),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: _cargando
            ? null
            : BarraAccion(
                total: t.total,
                habilitado: !_ctrl.guardando,
                texto: 'Terminar',
                onTap: () => _guardar(terminar: true),
              ),
      ),
    );
  }
}
