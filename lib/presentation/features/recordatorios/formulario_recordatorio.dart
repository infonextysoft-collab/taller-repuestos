import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/recordatorio.dart';
import '../../../domain/entities/repeticion.dart';
import '../../comunes/selector_repeticion.dart';
import '../../comunes/barra_accion.dart';

/// Alta y edición de un recordatorio suelto.
class FormularioRecordatorio extends ConsumerStatefulWidget {
  const FormularioRecordatorio({super.key, this.recordatorio});

  final Recordatorio? recordatorio;

  @override
  ConsumerState<FormularioRecordatorio> createState() =>
      _FormularioRecordatorioState();
}

class _FormularioRecordatorioState
    extends ConsumerState<FormularioRecordatorio> {
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _cliente = TextEditingController();
  final _equipo = TextEditingController();

  late String _fecha = hoyISO();
  Repeticion? _repetir;
  bool _guardando = false;

  bool get _esEdicion => widget.recordatorio != null;

  @override
  void initState() {
    super.initState();

    final r = widget.recordatorio;
    if (r != null) {
      _descripcion.text = r.descripcion;
      _cliente.text = r.cliente ?? '';
      _equipo.text = r.equipo ?? '';
      _fecha = r.fecha;
      _repetir = r.repite;
    }
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _cliente.dispose();
    _equipo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaDe(_fecha),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (elegida != null) setState(() => _fecha = isoDe(elegida));
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) {
      mostrarAviso(context, 'Revisa los campos marcados.', problema: true);
      return;
    }

    setState(() => _guardando = true);

    final repo = ref.read(recordatoriosRepoProvider);
    final base = widget.recordatorio;

    final registro = Recordatorio(
      id: base?.id,
      descripcion: _descripcion.text.trim(),
      fecha: _fecha,
      repite: _repetir,
      estado: base?.estado ?? EstadoRecordatorio.pendiente,
      origen: base?.origen ?? OrigenRecordatorio.manual,
      trabajoId: base?.trabajoId,
      cliente: _cliente.text.trim().isEmpty ? null : _cliente.text.trim(),
      equipo: _equipo.text.trim().isEmpty ? null : _equipo.text.trim(),
    );

    if (_esEdicion) {
      await repo.actualizar(registro);
    } else {
      await repo.crear(registro);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar recordatorio' : 'Nuevo recordatorio'),
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
                  etiqueta: 'Qué hay que recordar',
                  controlador: _descripcion,
                  ejemplo: 'Ej. Cambio de aceite del compresor',
                  lineas: 3,
                  autofoco: !_esEdicion,
                  validador: Valida.todos([
                    Valida.obligatorio('qué hay que recordar'),
                    Valida.minimo(4, 'La descripción'),
                  ]),
                ),
                const SizedBox(height: Espacio.lg),
                Seccion(
                  titulo: 'Cuándo',
                  child: InkWell(
                    onTap: _elegirFecha,
                    borderRadius: Redondeo.brChico,
                    child: Container(
                      padding: const EdgeInsets.all(Espacio.md),
                      decoration: BoxDecoration(
                        color: Tono.fondo,
                        borderRadius: Redondeo.brChico,
                        border: Border.all(color: Tono.linea),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded,
                              size: 19, color: Tono.texto2),
                          const SizedBox(width: Espacio.md),
                          Expanded(
                            child: Text(
                              formatoLargo(_fecha),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (estaVencida(_fecha))
                            const Insignia('Ya pasó',
                                color: Tono.vino, fondo: Tono.vinoSuave),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.lg),
                Seccion(
                  titulo: 'Repetir',
                  child: SelectorRepeticion(
                    valor: _repetir,
                    desde: _fecha,
                    onCambio: (v) => setState(() => _repetir = v),
                  ),
                ),
                const SizedBox(height: Espacio.lg),
                Campo(
                  etiqueta: 'Cliente',
                  controlador: _cliente,
                  ejemplo: 'De quién es',
                  opcional: true,
                ),
                const SizedBox(height: Espacio.lg),
                Campo(
                  etiqueta: 'Equipo',
                  controlador: _equipo,
                  ejemplo: 'Sobre qué equipo',
                  opcional: true,
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: BarraAccion(
        texto: _esEdicion ? 'Guardar cambios' : 'Crear recordatorio',
        habilitado: !_guardando,
        onTap: _guardar,
      ),
    );
  }
}
