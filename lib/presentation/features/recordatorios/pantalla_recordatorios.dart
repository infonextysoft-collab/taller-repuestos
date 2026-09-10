import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/pulsable.dart';
import '../../../domain/entities/recordatorio.dart';
import '../shell/barra_inferior.dart';
import 'formulario_recordatorio.dart';

/// Las tres vistas de Recordatorios.
///
/// Son tres y no seis. Seis recortes obligan a leer una grilla entera antes de
/// ver un solo recordatorio, y la mitad de ellos —"con lugar", "sin aviso"— son
/// preguntas que nadie se hace en un taller.
enum VistaAvisos { hoy, historial, importantes }

extension _VistaAvisosX on VistaAvisos {
  String get titulo => switch (this) {
        VistaAvisos.hoy => 'Hoy',
        VistaAvisos.historial => 'Historial',
        VistaAvisos.importantes => 'Importantes',
      };

  IconData get icono => switch (this) {
        VistaAvisos.hoy => Icons.today_rounded,
        VistaAvisos.historial => Icons.history_rounded,
        VistaAvisos.importantes => Icons.star_rounded,
      };
}

/// Mantenimientos y avisos.
class PantallaRecordatorios extends ConsumerStatefulWidget {
  const PantallaRecordatorios({super.key});

  @override
  ConsumerState<PantallaRecordatorios> createState() =>
      _PantallaRecordatoriosState();
}

class _PantallaRecordatoriosState extends ConsumerState<PantallaRecordatorios> {
  List<Recordatorio> _todos = const [];
  VistaAvisos _vista = VistaAvisos.hoy;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await ref.read(recordatoriosRepoProvider).listar();
    if (mounted) {
      setState(() {
        _todos = items;
        _cargando = false;
      });
    }
  }

  /* ------------------------------------------------------------- recortes */

  /// Lo que toca hoy: lo de hoy **y lo que ya venció**.
  ///
  /// Un vencido no deja de ser cosa de hoy por haber pasado de fecha: al
  /// contrario, es lo primero que hay que resolver. Separarlo en otra pestaña
  /// sería esconder justo lo que hay que hacer.
  List<Recordatorio> get _paraHoy {
    final hoy = hoyISO();
    final items = _todos
        .where((r) => !r.cumplido && r.fecha.compareTo(hoy) <= 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return items;
  }

  List<Recordatorio> get _importantes =>
      _todos.where((r) => r.importante && !r.cumplido).toList();

  /// Los tres últimos cumplidos, del más reciente al más viejo.
  List<Recordatorio> get _ultimosCumplidos {
    final items = _todos.where((r) => r.cumplido).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return items.take(3).toList();
  }

  List<GrupoRecordatorios> get _porMes {
    final grupos = <String, List<Recordatorio>>{};
    final ordenados = [..._todos]..sort((a, b) => b.fecha.compareTo(a.fecha));
    for (final r in ordenados) {
      grupos.putIfAbsent(claveMes(r.fecha), () => []).add(r);
    }
    return grupos.entries
        .map((e) => GrupoRecordatorios(e.key, e.value))
        .toList();
  }

  int _cuantos(VistaAvisos v) => switch (v) {
        VistaAvisos.hoy => _paraHoy.length,
        VistaAvisos.historial => _todos.length,
        VistaAvisos.importantes => _importantes.length,
      };

  /* ------------------------------------------------------------ acciones */

  Future<void> _abrirFormulario([Recordatorio? recordatorio]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormularioRecordatorio(recordatorio: recordatorio),
      ),
    );

    if (guardado == true && mounted) await _refrescar();
  }

  Future<void> _refrescar() async {
    ref.read(refrescoRecordatoriosProvider.notifier).state++;
    ref.invalidate(vencidosProvider);
    await _cargar();
  }

  Future<void> _cumplir(Recordatorio r) async {
    final siguiente =
        await ref.read(recordatoriosRepoProvider).marcarCumplido(r.id!);
    if (!mounted) return;

    mostrarAviso(
      context,
      siguiente == null
          ? 'Listo, marcado como hecho.'
          : 'Hecho. El próximo queda para '
              '${formatoCorto(r.repite!.siguiente(r.fecha))}.',
    );
    await _refrescar();
  }

  Future<void> _destacar(Recordatorio r) async {
    await ref
        .read(recordatoriosRepoProvider)
        .marcarImportante(r.id!, !r.importante);
    if (mounted) await _refrescar();
  }

  Future<void> _eliminar(Recordatorio r) async {
    final seguro = await confirmar(
      context,
      titulo: '¿Eliminar el recordatorio?',
      mensaje: r.descripcion,
      aceptar: 'Eliminar',
      cancelar: 'Permanecer',
      destructivo: true,
    );
    if (!seguro) return;

    await ref.read(recordatoriosRepoProvider).eliminar(r.id!);
    if (mounted) await _refrescar();
  }

  /* ---------------------------------------------------------------- vista */

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoRecordatoriosProvider, (_, _) => _cargar());

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
              Espacio.lg,
            ),
            child: Row(
              children: [
                for (final v in VistaAvisos.values) ...[
                  Expanded(
                    child: _Ficha(
                      vista: v,
                      cantidad: _cuantos(v),
                      activa: v == _vista,
                      onTap: () => setState(() => _vista = v),
                    ),
                  ),
                  if (v != VistaAvisos.values.last)
                    const SizedBox(width: Espacio.sm),
                ],
              ],
            ),
          ),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.only(top: Espacio.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._contenido(),
        ],
      ),
    );
  }

  List<Widget> _contenido() => switch (_vista) {
        VistaAvisos.hoy => [
            _seccion(
              'Pendientes para hoy',
              _paraHoy,
              vacio: 'Nada para hoy. Todo al día.',
            ),
            _seccion(
              'Últimos 3 cumplidos',
              _ultimosCumplidos,
              vacio: 'Todavía no marcaste ninguno como hecho.',
            ),
          ],
        VistaAvisos.importantes => [
            _seccion(
              'Marcados como importantes',
              _importantes,
              vacio: 'Toca la estrella de un recordatorio para tenerlo aquí.',
            ),
          ],
        VistaAvisos.historial => [
            if (_todos.isEmpty)
              const Contenido(
                child: EstadoVacio(
                  icono: Icons.notifications_none_rounded,
                  titulo: 'No hay nada agendado',
                  detalle: 'Los mantenimientos también salen solos del paso de '
                      'Recomendaciones al cerrar un trabajo.',
                ),
              )
            else
              for (final grupo in _porMes)
                _bloque(nombreMes(grupo.mes), grupo.items),
            _NuevoRecordatorio(onTap: _abrirFormulario),
          ],
      };

  Widget _seccion(String titulo, List<Recordatorio> items,
          {required String vacio}) =>
      items.isEmpty
          ? Contenido(
              padding: const EdgeInsets.fromLTRB(
                Espacio.lg,
                0,
                Espacio.lg,
                Espacio.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titulo.toUpperCase(), style: Tipo.etiqueta),
                  const SizedBox(height: Espacio.md),
                  Panel(
                    child: Text(vacio, style: Tipo.secundario),
                  ),
                  const SizedBox(height: Espacio.md),
                  _NuevoRecordatorio(onTap: _abrirFormulario),
                ],
              ),
            )
          : _bloque(titulo, items);

  Widget _bloque(String titulo, List<Recordatorio> items) => Contenido(
        padding: const EdgeInsets.fromLTRB(
          Espacio.lg,
          0,
          Espacio.lg,
          Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo.toUpperCase(), style: Tipo.etiqueta),
            const SizedBox(height: Espacio.md),
            ListaAgrupada(
              filas: [
                for (final r in items)
                  _FilaRecordatorio(
                    recordatorio: r,
                    onTap: () => _abrirFormulario(r),
                    onCumplir: () => _cumplir(r),
                    onDestacar: () => _destacar(r),
                    onEliminar: () => _eliminar(r),
                  ),
              ],
            ),
          ],
        ),
      );
}

/// Una de las tres fichas de arriba. Es pestaña y contador a la vez.
///
/// Activa = superficie oscura con el número en oro. La diferencia la da el
/// peso de la superficie, igual que en el resto de la app.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.vista,
    required this.cantidad,
    required this.activa,
    required this.onTap,
  });

  final VistaAvisos vista;
  final int cantidad;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.96,
        semantica: vista.titulo,
        child: AnimatedContainer(
          duration: duracion(context, Movimiento.micro),
          curve: Movimiento.salida,
          padding: const EdgeInsets.symmetric(
            horizontal: Espacio.md,
            vertical: Espacio.md,
          ),
          decoration: BoxDecoration(
            color: activa ? Tono.negro : Tono.fondo,
            borderRadius: Redondeo.brNormal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                vista.icono,
                size: 18,
                color: activa ? Tono.oroVivo : Tono.texto3,
              ),
              const SizedBox(height: Espacio.sm),
              Text(
                '$cantidad',
                style: Tipo.titulo1.copyWith(
                  fontSize: 24,
                  color: activa ? Tono.textoInverso : Tono.texto,
                  fontFeatures: kNumerosTabulares,
                ),
              ),
              Text(
                vista.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipo.nota.copyWith(
                  color: activa ? Tono.textoInverso2 : Tono.texto3,
                ),
              ),
            ],
          ),
        ),
      );
}

/// El alta va acá y no en un botón flotante: la barra de abajo ahora flota, y
/// un botón flotante encima de otro se tapan entre sí.
class _NuevoRecordatorio extends StatelessWidget {
  const _NuevoRecordatorio({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_alert_rounded, size: 19),
        label: const Text('Nuevo recordatorio'),
      );
}

class _FilaRecordatorio extends StatelessWidget {
  const _FilaRecordatorio({
    required this.recordatorio,
    required this.onTap,
    required this.onCumplir,
    required this.onDestacar,
    required this.onEliminar,
  });

  final Recordatorio recordatorio;
  final VoidCallback onTap;
  final VoidCallback onCumplir;
  final VoidCallback onDestacar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;

    final (etiqueta, color, fondo) = switch (r.estado) {
      EstadoRecordatorio.vencido => ('Vencido', Tono.vinoTexto, Tono.vinoSuave),
      EstadoRecordatorio.cumplido => ('Hecho', Tono.oroTexto, Tono.oroSuave),
      EstadoRecordatorio.pendiente => (
          formatoCorto(r.fecha),
          Tono.texto2,
          Tono.fondo2
        ),
    };

    return FilaLista(
      onTap: r.cumplido ? null : onTap,
      onLongPress: r.cumplido ? null : onEliminar,
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
                Text(
                  r.descripcion.trim().isEmpty
                      ? 'Sin descripción'
                      : r.descripcion.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tipo.encabezado,
                ),
                const SizedBox(height: Espacio.sm),
                Wrap(
                  spacing: Espacio.sm,
                  runSpacing: Espacio.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Insignia(etiqueta, color: color, fondo: fondo),
                    if (r.seRepite)
                      Insignia(
                        r.repite!.corta,
                        icono: Icons.autorenew_rounded,
                        color: Tono.texto2,
                        fondo: Tono.fondo2,
                      ),
                    if ((r.cliente ?? '').trim().isNotEmpty ||
                        (r.equipo ?? '').trim().isNotEmpty)
                      Text(
                        [
                          if ((r.cliente ?? '').trim().isNotEmpty)
                            r.cliente!.trim(),
                          if ((r.equipo ?? '').trim().isNotEmpty)
                            r.equipo!.trim(),
                        ].join(' · '),
                        style: Tipo.nota.copyWith(color: Tono.texto3),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!r.cumplido) ...[
            IconButton(
              onPressed: onDestacar,
              iconSize: 21,
              visualDensity: VisualDensity.compact,
              color: r.importante ? Tono.oro : Tono.texto3,
              tooltip: r.importante ? 'Quitar de importantes' : 'Importante',
              icon: Icon(
                r.importante ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
            ),
            IconButton(
              onPressed: onCumplir,
              iconSize: 23,
              color: Tono.oro,
              tooltip: 'Marcar hecho',
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
          ] else
            IconButton(
              onPressed: onEliminar,
              iconSize: 19,
              visualDensity: VisualDensity.compact,
              color: Tono.texto3,
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}
