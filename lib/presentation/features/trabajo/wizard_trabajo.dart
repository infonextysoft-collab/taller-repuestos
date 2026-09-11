import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/trabajo.dart';
import '../../comunes/barra_accion.dart';
import '../../comunes/controlador_registro.dart';
import '../documento/pantalla_documento.dart';
import 'pasos_wizard.dart';

/// El wizard de un trabajo, en seis pasos.
///
/// No pregunta al empezar si fue en taller o en campo: es el mismo formulario
/// y el mismo flujo, y la única diferencia real —dónde se hizo y si se cobra
/// traslado— se pregunta adentro, en el paso del lugar, cuando ya hay contexto
/// para contestarla.
///
/// El orden importa y ya fue corregido una vez: **las dos tandas de fotos van
/// pegadas al principio**, antes del lugar. En el sitio se saca el celular, se
/// fotografía cómo llega el equipo y cómo queda, y recién ahí se completa el
/// resto con calma.
///
/// Semántica de guardado:
///   - El registro **nace en `pendiente` al pasar del paso 1**. Se puede
///     cerrar la app en cualquier momento y volver después.
///   - Guardar en el paso N cierra **todos** los pasos 1..N, no solo el N.
///   - Hay "Salir" en todos los pasos, no solo en el primero.
class WizardTrabajo extends ConsumerStatefulWidget {
  const WizardTrabajo({super.key, this.id});

  /// `null` = trabajo nuevo.
  final int? id;

  @override
  ConsumerState<WizardTrabajo> createState() => _WizardTrabajoState();
}

class _WizardTrabajoState extends ConsumerState<WizardTrabajo> {
  static const List<String> titulos = [
    'Cliente y equipo',
    'Fotos',
    'Lugar y diagnóstico',
    'Qué se cobra',
    'Recomendaciones',
    'Totales',
  ];

  static int get _cantidadPasos => titulos.length;

  late final ControladorRegistro _ctrl = ControladorRegistro(
    ref.read(trabajosRepoProvider),
    ref.read(inventarioRepoProvider),
    ref.read(recordatoriosRepoProvider),
  );

  final _campos = CamposWizard();

  /// Una clave de formulario **por paso**, no una compartida.
  ///
  /// Mientras la transición corre, el paso que sale y el que entra están los
  /// dos en el árbol. Con una sola clave, Flutter detectaba la misma
  /// `GlobalKey` dos veces y desenganchaba el formulario viejo de su lugar
  /// —un error en rojo en cada "Siguiente", y el riesgo de que el paso que se
  /// va pierda lo que tenía cargado—.
  final Map<int, GlobalKey<FormState>> _formularios = {};

  GlobalKey<FormState> _formDe(int paso) =>
      _formularios.putIfAbsent(paso, GlobalKey<FormState>.new);

  int _paso = 1;
  bool _haciaAdelante = true;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_alCambiar);
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (widget.id == null) {
      _ctrl.empezar(TipoTrabajo.taller);
    } else {
      await _ctrl.cargar(widget.id!);
      _campos.sembrar(_ctrl.registro);
      // Al volver a un pendiente, se retoma en el primer paso sin cerrar.
      final guardados = _ctrl.registro.pasosGuardados;
      _paso = guardados.isEmpty
          ? 1
          : (guardados.reduce((a, b) => a > b ? a : b) + 1)
              .clamp(1, _cantidadPasos);
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
    _campos.dispose();
    super.dispose();
  }

  bool get _bloqueado => _ctrl.pasoBloqueado(_paso);

  Future<void> _siguiente() async {
    // Cada paso valida lo suyo antes de dejar avanzar: descubrir en el paso 9
    // que falta el cliente del paso 1 obliga a volver ocho pantallas.
    final formulario = _formDe(_paso).currentState;
    if (formulario != null && !formulario.validate()) {
      mostrarAviso(context, 'Revisa los campos marcados.', problema: true);
      return;
    }

    if (_paso == 4 &&
        _ctrl.registro.trabajosRealizados.isEmpty &&
        _ctrl.registro.repuestos.isEmpty) {
      mostrarAviso(
        context,
        'Agrega al menos un trabajo o un repuesto: si no, el documento sale '
        'en cero.',
        problema: true,
      );
      return;
    }

    await _ctrl.guardarPaso(_paso);

    if (_paso >= _cantidadPasos) {
      await _terminar();
      return;
    }

    setState(() {
      _haciaAdelante = true;
      _paso++;
    });
  }

  void _atras() {
    if (_paso <= 1) return;
    setState(() {
      _haciaAdelante = false;
      _paso--;
    });
  }

  Future<void> _terminar() async {
    final registro = await _ctrl.terminar();
    if (!mounted) return;

    ref.read(refrescoHistorialProvider.notifier).state++;
    ref.read(refrescoInventarioProvider.notifier).state++;
    ref.read(refrescoRecordatoriosProvider.notifier).state++;
    ref.invalidate(vencidosProvider);

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PantallaDocumento(id: registro.id!)),
    );
  }

  /// Salir: o se permanece, o se guarda y se sale. Lo escrito ya está en la
  /// base desde el primer paso, así que no hay nada que "descartar".
  Future<bool> _intentarSalir() async {
    if (!_ctrl.hayCambios && _ctrl.registro.id == null) return true;

    final decision = await confirmarSalida(context);

    switch (decision) {
      case SalidaWizard.permanecer:
        return false;

      case SalidaWizard.guardar:
        await _ctrl.guardar();
        if (mounted) {
          ref.read(refrescoHistorialProvider.notifier).state++;
          mostrarAviso(
            context,
            'Guardado como pendiente. Sigue cuando quieras.',
          );
        }
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ultimo = _paso == _cantidadPasos;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (yaSalio, _) async {
        if (yaSalio) return;
        final salir = await _intentarSalir();
        if (!context.mounted) return;
        if (salir) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final salir = await _intentarSalir();
              if (!context.mounted) return;
              if (salir) Navigator.of(context).pop();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulos[_paso - 1], style: Tipo.encabezado),
              Text(
                'Paso $_paso de $_cantidadPasos'
                '${_ctrl.registro.codigo.isEmpty ? '' : ' · ${_ctrl.registro.codigo}'}',
                style: Tipo.nota,
              ),
            ],
          ),
          actions: [
            if (_bloqueado)
              TextButton(
                onPressed: () => _ctrl.reabrirPaso(_paso),
                child: const Text('Editar'),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _Progreso(paso: _paso, total: _cantidadPasos),
          ),
        ),
        body: TransicionDireccional(
          indice: _paso,
          haciaAdelante: _haciaAdelante,
          child: _CuerpoPaso(
            formKey: _formDe(_paso),
            paso: _paso,
            ctrl: _ctrl,
            campos: _campos,
            bloqueado: _bloqueado,
            onAviso: (m) => mostrarAviso(context, m),
          ),
        ),
        bottomNavigationBar: BarraAccion(
          total: ultimo ? _ctrl.totales.total : null,
          texto: ultimo ? 'Terminar' : 'Siguiente',
          habilitado: !_ctrl.guardando,
          onTap: _siguiente,
          secundario: _paso > 1
              ? SizedBox(
                  width: 54,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _atras,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Tono.texto2),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// El cuerpo del paso.
///
/// El `Form` se rearma en cada paso —la clave lleva el número— porque si se
/// compartiera, los campos de un paso que ya no está en pantalla seguirían
/// contando como inválidos al validar.
class _CuerpoPaso extends StatelessWidget {
  const _CuerpoPaso({
    required this.formKey,
    required this.paso,
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
    required this.onAviso,
  });

  final GlobalKey<FormState> formKey;
  final int paso;
  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;
  final ValueChanged<String> onAviso;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: ListView(
          key: ValueKey('cuerpo-$paso'),
          padding: const EdgeInsets.only(
            top: Espacio.lg,
            bottom: Espacio.xxxl,
          ),
          children: [
            Contenido(
              child: PasoWizard(
                paso: paso,
                ctrl: ctrl,
                campos: campos,
                bloqueado: bloqueado,
                onAviso: onAviso,
              ),
            ),
          ],
        ),
      );
}

/// La barra de avance: un tramo por paso, no una línea continua.
///
/// Un porcentaje no dice cuánto falta cuando los pasos duran cosas distintas;
/// los tramos sí dejan contar de un vistazo.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.total});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.lg,
          0,
          Espacio.lg,
          Espacio.sm,
        ),
        child: Row(
          children: [
            for (var i = 1; i <= total; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == total ? 0 : 3),
                  child: AnimatedContainer(
                    duration: duracion(context, Movimiento.normal),
                    curve: Movimiento.salida,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= paso ? Tono.vino : Tono.linea,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
