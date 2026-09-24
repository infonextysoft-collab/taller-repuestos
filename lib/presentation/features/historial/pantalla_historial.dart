import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/foto.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/trabajo.dart';
import '../../../domain/repositories/trabajos_repository.dart';
import '../../../domain/services/ganancia.dart';
import '../../comunes/salida_pdf.dart';
import '../shell/barra_inferior.dart';
import '../documento/pantalla_documento.dart';
import '../trabajo/wizard_trabajo.dart';
import '../venta/pantalla_venta_simple.dart';
import 'filtros_historial.dart';
import 'tarjetas_resumen.dart';

/// Los recortes rápidos del historial.
///
/// Son una sola fila de un solo valor a la vez, y mezclan estado con tipo a
/// propósito: no son dos filtros combinables, son **vistas**. "Mostrame los
/// pendientes" y "mostrame lo del taller" son la misma pregunta hecha de dos
/// maneras, y una fila con contador contesta las dos sin abrir nada.
enum VistaHistorial { todos, pendientes, completados, taller, campo, ventas }

extension _VistaX on VistaHistorial {
  String get chip => switch (this) {
        VistaHistorial.todos => 'Todos',
        VistaHistorial.pendientes => 'Pendientes',
        VistaHistorial.completados => 'Completados',
        VistaHistorial.taller => 'En taller',
        VistaHistorial.campo => 'En campo',
        VistaHistorial.ventas => 'Ventas',
      };

  bool acepta(Trabajo t) => switch (this) {
        VistaHistorial.todos => true,
        VistaHistorial.pendientes => !t.estaTerminado,
        VistaHistorial.completados => t.estaTerminado,
        VistaHistorial.taller => t.tipo == TipoTrabajo.taller,
        VistaHistorial.campo => t.tipo == TipoTrabajo.campo,
        VistaHistorial.ventas => t.tipo == TipoTrabajo.venta,
      };
}

/// Todo lo registrado, lo más reciente arriba.
class PantallaHistorial extends ConsumerStatefulWidget {
  const PantallaHistorial({super.key, required this.onSeccion});

  /// Las tarjetas de arriba llevan a Avisos o a Inventario, que son otras
  /// pestañas del armazón: el historial no las conoce, solo avisa a dónde ir.
  final ValueChanged<int> onSeccion;

  @override
  ConsumerState<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends ConsumerState<PantallaHistorial> {
  FiltroHistorial _filtro = const FiltroHistorial();
  VistaHistorial _vista = VistaHistorial.todos;
  List<Trabajo> _items = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await ref.read(trabajosRepoProvider).listar(_filtro);
    if (mounted) {
      setState(() {
        _items = items;
        _cargando = false;
      });
    }
  }

  /// Lo que se ve después de aplicar el chip.
  ///
  /// El recorte se hace acá y no en la consulta a propósito: teniendo la lista
  /// completa en la mano, los contadores de cada chip salen gratis, y un chip
  /// sin contador te hace tocarlo para descubrir que está vacío.
  List<Trabajo> get _visibles => _items.where(_vista.acepta).toList();

  int _cuantos(VistaHistorial v) => _items.where(v.acepta).length;

  /* ------------------------------------------------------------ acciones */

  /// Tocar la fila hace **lo que se venía a hacer**: si está a medias, seguir
  /// cargándolo; si está cerrado, ver el documento. El resto vive detrás del
  /// botón de puntos, que es donde se busca lo que se usa poco.
  void _abrir(Trabajo t) {
    if (t.estaTerminado) {
      _verDocumento(t);
    } else {
      _editar(t);
    }
  }

  Future<void> _masAcciones(Trabajo t) async {
    await mostrarHoja<void>(
      context,
      titulo: t.cliente.trim().isEmpty ? 'Sin cliente' : t.cliente.trim(),
      bajada: '${t.codigo} · ${formatoCorto(t.fecha)}',
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
            _ResumenHoja(trabajo: t),
            const SizedBox(height: Espacio.xl),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(hoja).pop();
                _verDocumento(t);
              },
              icon: const Icon(Icons.description_rounded, size: 20),
              label: const Text('Ver documento'),
            ),
            const SizedBox(height: Espacio.md),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(hoja).pop();
                _editar(t);
              },
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: Text(t.estaTerminado ? 'Editar' : 'Seguir cargando'),
            ),
            const SizedBox(height: Espacio.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(hoja).pop();
                    _sacarPdf(t, compartir: false);
                  },
                  icon: const Icon(Icons.download_rounded, size: 19),
                  label: const Text('Descargar PDF'),
                ),
                Container(
                  width: 1,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: Espacio.sm),
                  color: Tono.linea,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(hoja).pop();
                    _sacarPdf(t, compartir: true);
                  },
                  tooltip: 'Compartir',
                  color: Tono.vinoTexto,
                  icon: const Icon(Icons.share_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verDocumento(Trabajo t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaDocumento(id: t.id!)),
    );
  }

  Future<void> _editar(Trabajo t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => t.tipo == TipoTrabajo.venta
            ? PantallaVentaSimple(id: t.id)
            : WizardTrabajo(id: t.id),
      ),
    );
    if (mounted) {
      ref.read(refrescoInventarioProvider.notifier).state++;
      await _cargar();
    }
  }

  /// Descargar lo deja en el teléfono; compartir abre la hoja del sistema.
  Future<void> _sacarPdf(Trabajo t, {required bool compartir}) async {
    try {
      final negocio = ref.read(negocioProvider);
      final bytes = await ref.read(generadorPdfProvider).completo(t, negocio);
      final nombre = '${t.codigo}.pdf';

      if (compartir) {
        await compartirPdf(bytes, nombre, mensaje: mensajeDeEnvio(t, negocio));
      } else if (mounted) {
        await descargarPdf(context, bytes, nombre);
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo sacar el PDF: $e', problema: true);
      }
    }
  }

  /* ---------------------------------------------------------------- vista */

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoHistorialProvider, (_, _) => _cargar());

    final visibles = _visibles;
    final resumen = ref.watch(resumenProvider);

    return RefreshIndicator(
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
              0,
            ),
            child: resumen.when(
              data: (r) => TarjetasResumen(
                resumen: r,
                onAvisos: () => widget.onSeccion(2),
                onSinCerrar: () =>
                    setState(() => _vista = VistaHistorial.pendientes),
                onInventario: () {
                  ref.read(pedidoAgotadosProvider.notifier).state++;
                  widget.onSeccion(1);
                },
              ),
              // Ni carga ni error tienen por qué gritar: es un resumen, y la
              // lista de abajo funciona igual sin él.
              loading: () => const SizedBox(height: 168),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          Contenido(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lg,
              Espacio.lg,
              Espacio.lg,
              Espacio.md,
            ),
            child: FiltrosHistorial(
              filtro: _filtro,
              onCambio: (f) {
                setState(() => _filtro = f);
                _cargar();
              },
            ),
          ),
          _ChipsVista(
            actual: _vista,
            cuantos: _cuantos,
            onElegir: (v) => setState(() => _vista = v),
          ),
          const SizedBox(height: Espacio.md),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.only(top: Espacio.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibles.isEmpty)
            Contenido(
              child: EstadoVacio(
                icono: Icons.receipt_long_rounded,
                titulo: _filtro.vacio && _vista == VistaHistorial.todos
                    ? 'Todavía no registras nada'
                    : 'Nada por aquí',
                detalle: _filtro.vacio && _vista == VistaHistorial.todos
                    ? 'Toca el + de abajo para cargar tu primer trabajo o '
                        'venta.'
                    : 'Con este recorte no hay registros. Prueba con otro.',
              ),
            )
          else
            Contenido(
              child: ListaAgrupada(
                filas: [
                  for (final t in visibles)
                    _FilaHistorial(
                      trabajo: t,
                      onTap: () => _abrir(t),
                      onMas: () => _masAcciones(t),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// La fila de chips. Va a ancho completo y desborda al costado: recortarla al
/// ancho del contenido dejaría medio chip cortado en pantallas chicas.
class _ChipsVista extends StatelessWidget {
  const _ChipsVista({
    required this.actual,
    required this.cuantos,
    required this.onElegir,
  });

  final VistaHistorial actual;
  final int Function(VistaHistorial) cuantos;
  final ValueChanged<VistaHistorial> onElegir;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
          children: [
            for (final v in VistaHistorial.values) ...[
              _Chip(
                texto: v.chip,
                cantidad: cuantos(v),
                activo: v == actual,
                onTap: () => onElegir(v),
              ),
              const SizedBox(width: Espacio.sm),
            ],
          ],
        ),
      );
}

/// Un chip con su contador.
///
/// Activo = relleno vino con el número en oro. Inactivo = superficie blanca.
/// La diferencia la da el **peso de la superficie**, no un tercer color.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.cantidad,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final int cantidad;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: activo ? Tono.vino : Tono.fondo,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
            child: Row(
              children: [
                Text(
                  texto,
                  style: Tipo.nota.copyWith(
                    fontSize: 13,
                    color: activo ? Tono.textoInverso : Tono.texto2,
                  ),
                ),
                const SizedBox(width: Espacio.sm),
                Text(
                  '$cantidad',
                  style: Tipo.nota.copyWith(
                    fontSize: 13,
                    color: activo ? Tono.oroClaro : Tono.texto3,
                    fontFeatures: kNumerosTabulares,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Una fila del historial.
///
/// Lleva la **foto del equipo** adelante. La app ya la saca en el paso 2 y no
/// se mostraba en ningún lado; es el único material visual propio que tiene la
/// app y reconocer un trabajo por la máquina es más rápido que leer un código.
class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({
    required this.trabajo,
    required this.onTap,
    required this.onMas,
  });

  final Trabajo trabajo;
  final VoidCallback onTap;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    final t = trabajo;
    final cliente = t.cliente.trim().isEmpty ? 'Sin cliente' : t.cliente.trim();

    return FilaLista(
      onTap: onTap,
      onLongPress: onMas,
      padding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        Espacio.md,
        Espacio.xs,
        Espacio.md,
      ),
      child: Row(
        children: [
          Miniatura(foto: t.miniatura, nombre: cliente),
          const SizedBox(width: Espacio.md),
          // El nombre manda en la primera línea y el importe la cierra; lo
          // demás baja a la segunda. Cuando todo iba en un renglón, el nombre
          // se comía los puntos suspensivos a los ocho caracteres.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tipo.encabezado,
                      ),
                    ),
                    const SizedBox(width: Espacio.sm),
                    Text(soles(t.totales.total), style: Tipo.monto),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (!t.estaTerminado) ...[
                      const Insignia(
                        'Sin cerrar',
                        color: Tono.vinoTexto,
                        fondo: Tono.vinoSuave,
                      ),
                      const SizedBox(width: Espacio.sm),
                    ],
                    Expanded(
                      child: Text(
                        [
                          if (t.equipo.trim().isNotEmpty)
                            t.equipo.trim()
                          else
                            t.tipo.etiqueta,
                          formatoCorto(t.fecha),
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tipo.nota.copyWith(color: Tono.texto3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMas,
            tooltip: 'Más',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 44),
            icon: const Icon(Icons.more_horiz_rounded, color: Tono.texto3),
          ),
        ],
      ),
    );
  }
}

/// La cabecera de la hoja de acciones: quién, cuánto y en qué estado.
///
/// Reemplaza a la lista de cuatro filas iguales con flechita que había antes.
/// Antes de elegir una acción hay que saber sobre qué registro se está
/// actuando, y el importe es lo que lo identifica de verdad.
class _ResumenHoja extends StatelessWidget {
  const _ResumenHoja({required this.trabajo});

  final Trabajo trabajo;

  @override
  Widget build(BuildContext context) {
    final ganancia = gananciaDe(trabajo);

    return Panel(
      color: Tono.fondo2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(),
          // Solo con algo cobrado: "ganaste S/ 0.00" en un registro a medias
          // no es un dato, es ruido.
          if (ganancia.cobrado > 0) ...[
            const SizedBox(height: Espacio.md),
            const Divider(height: 1, color: Tono.linea),
            const SizedBox(height: Espacio.md),
            _Ganancia(ganancia: ganancia),
          ],
        ],
      ),
    );
  }

  Widget _encabezado() => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trabajo.estaTerminado ? 'Completado' : 'Sin cerrar',
                    style: Tipo.etiqueta.copyWith(
                      color: trabajo.estaTerminado
                          ? Tono.oroTexto
                          : Tono.vinoTexto,
                    ),
                  ),
                  const SizedBox(height: Espacio.xs),
                  Text(
                    trabajo.equipo.trim().isEmpty
                        ? trabajo.tipo.etiqueta
                        : trabajo.equipo.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.secundario,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espacio.md),
            Text(soles(trabajo.totales.total), style: Tipo.montoGrande),
          ],
        );
}

/// Cuánto quedó después de reponer los repuestos.
///
/// Si alguna línea no dice lo que costó, se avisa **con el número**: no es lo
/// mismo dudar de uno que de siete, y sin esa cuenta la ganancia parece
/// exacta cuando en realidad es un techo.
class _Ganancia extends StatelessWidget {
  const _Ganancia({required this.ganancia});

  final Ganancia ganancia;

  @override
  Widget build(BuildContext context) {
    final g = ganancia;
    final faltan = g.sinCosto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                g.completa ? 'Ganancia' : 'Ganancia, como mucho',
                style: Tipo.secundario,
              ),
            ),
            Text(
              soles(g.neta),
              style: Tipo.monto.copyWith(
                color: g.neta < 0 ? Tono.vino : Tono.oroTexto,
              ),
            ),
          ],
        ),
        if (!g.completa) ...[
          const SizedBox(height: Espacio.xs),
          Text(
            faltan == 1
                ? 'Hay 1 repuesto sin costo registrado.'
                : 'Hay $faltan repuestos sin costo registrado.',
            style: Tipo.nota,
          ),
        ],
      ],
    );
  }
}
