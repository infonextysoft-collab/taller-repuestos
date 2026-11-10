import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/recordatorio.dart';
import '../../../domain/services/historial_avisos.dart';
import 'acciones_aviso.dart';
import 'tarjeta_aviso.dart';

String _nombreDelMes(String clave) => nombreMes(clave).split(' ').first;

String _resumenDe(MesDeAvisos m) {
  if (m.cuantos > 0) return '${m.cumplidos.length} de ${m.cuantos} cumplidos';
  return m.eliminados.length == 1
      ? '1 eliminado'
      : '${m.eliminados.length} eliminados';
}

/// El historial: mes por mes, de un año a la vez.
///
/// No se borra nada solo: todos los años quedan a mano, y el símbolo para
/// cambiar de año aparece recién cuando hay más de uno entre los que elegir.
class PantallaCompletados extends ConsumerStatefulWidget {
  const PantallaCompletados({super.key});

  @override
  ConsumerState<PantallaCompletados> createState() =>
      _PantallaCompletadosState();
}

class _PantallaCompletadosState extends ConsumerState<PantallaCompletados> {
  List<Recordatorio> _todos = const [];
  late int _anio = fechaDe(hoyISO()).year;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todos = await ref
        .read(recordatoriosRepoProvider)
        .listar(incluirEliminados: true);

    if (!mounted) return;
    setState(() {
      _todos = todos;
      _cargando = false;
    });
  }

  Future<void> _elegirAnio(List<int> anios) async {
    final elegido = await mostrarHoja<int>(
      context,
      titulo: 'Elige el año',
      contenido: (hoja) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in anios)
            ListTile(
              onTap: () => Navigator.of(hoja).pop(a),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Espacio.xl,
              ),
              title: Text('$a', style: Tipo.titulo2),
              trailing: a == _anio
                  ? const Icon(Icons.check_rounded, color: Tono.vino)
                  : null,
            ),
          const SizedBox(height: Espacio.md),
        ],
      ),
    );

    if (elegido != null && mounted) setState(() => _anio = elegido);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoRecordatoriosProvider, (_, _) => _cargar());

    final anios = aniosDelHistorial(_todos);
    final meses = mesesDelAnio(_todos, _anio);
    final cambiaAnio = anios.length > 1;

    return Scaffold(
      backgroundColor: Tono.fondo2,
      appBar: AppBar(
        title: const Text('Completados'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Espacio.md),
            child: Center(
              child: InkWell(
                onTap: cambiaAnio ? () => _elegirAnio(anios) : null,
                borderRadius: Redondeo.brChico,
                child: Container(
                  constraints: const BoxConstraints(minHeight: kAreaTactil),
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_anio', style: Tipo.titulo2),
                      if (cambiaAnio)
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 26,
                          color: Tono.texto,
                          semanticLabel: 'Cambiar de año',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : meses.isEmpty
          ? Center(
              child: EstadoVacio(
                icono: Icons.history_rounded,
                titulo: 'Todavía no hay avisos de este año',
                detalle: _anioAnterior(anios) == null
                    ? 'Aquí van a aparecer los avisos que ya pasaron.'
                    : 'Toca el año para ver ${_anioAnterior(anios)}.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(
                top: Espacio.lg,
                bottom: Espacio.xxl,
              ),
              children: [
                for (final m in meses)
                  Contenido(
                    padding: const EdgeInsets.fromLTRB(
                      Espacio.lg,
                      0,
                      Espacio.lg,
                      Espacio.md,
                    ),
                    child: _TarjetaMes(mes: m, onTap: () => _abrirMes(m.clave)),
                  ),
              ],
            ),
    );
  }

  int? _anioAnterior(List<int> anios) {
    for (final a in anios) {
      if (a != _anio) return a;
    }
    return null;
  }

  void _abrirMes(String clave) => mostrarHoja<void>(
    context,
    titulo: nombreMes(clave),
    contenido: (hoja) => _VentanaMes(clave: clave),
  );
}

class _TarjetaMes extends StatelessWidget {
  const _TarjetaMes({required this.mes, required this.onTap});

  final MesDeAvisos mes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_nombreDelMes(mes.clave), style: Tipo.titulo2),
              const SizedBox(height: 2),
              Text(_resumenDe(mes), style: Tipo.secundario),
              if (mes.cuantos > 0) ...[
                const SizedBox(height: Espacio.md),
                _Avance(valor: mes.avance),
              ],
            ],
          ),
        ),
        const SizedBox(width: Espacio.sm),
        const Icon(Icons.chevron_right_rounded, size: 24, color: Tono.texto3),
      ],
    ),
  );
}

class _Avance extends StatelessWidget {
  const _Avance({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: valor,
      minHeight: 8,
      color: Tono.oro,
      backgroundColor: Tono.fondo2,
    ),
  );
}

/// La ventana de un mes: lo cumplido, lo que quedó sin cumplir y lo eliminado.
///
/// Lee la base por su cuenta y se vuelve a armar después de cada acción: las
/// filas cambian de lista adentro de la misma ventana.
class _VentanaMes extends ConsumerStatefulWidget {
  const _VentanaMes({required this.clave});

  final String clave;

  @override
  ConsumerState<_VentanaMes> createState() => _VentanaMesState();
}

class _VentanaMesState extends ConsumerState<_VentanaMes> {
  MesDeAvisos? _mes;

  int get _anio => int.tryParse(widget.clave.split('-').first) ?? 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todos = await ref
        .read(recordatoriosRepoProvider)
        .listar(incluirEliminados: true);
    if (!mounted) return;

    final meses = mesesDelAnio(todos, _anio);
    setState(() {
      _mes = meses.where((m) => m.clave == widget.clave).firstOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoRecordatoriosProvider, (_, _) => _cargar());

    final m = _mes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.xl, 0, Espacio.xl, Espacio.xl),
      child: m == null
          ? Text('Ya no queda nada en este mes.', style: Tipo.secundario)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_resumenDe(m), style: Tipo.secundario),
                if (m.cuantos > 0) ...[
                  const SizedBox(height: Espacio.sm),
                  _Avance(valor: m.avance),
                ],
                if (m.cumplidos.isNotEmpty)
                  _Seccion(
                    titulo: 'Cumplidos',
                    filas: [
                      for (final r in m.cumplidos)
                        _Fila(
                          recordatorio: r,
                          pie: r.cumplidoEl == null
                              ? 'Cumplido'
                              : 'Cumplido el ${diaMes(r.cumplidoEl!)}',
                          alFinal: const Icon(
                            Icons.check_circle_rounded,
                            size: 24,
                            color: Tono.oro,
                          ),
                        ),
                    ],
                  ),
                if (m.sinCumplir.isNotEmpty)
                  _Seccion(
                    titulo: 'Sin cumplir',
                    filas: [
                      for (final r in m.sinCumplir)
                        _Fila(
                          recordatorio: r,
                          pie: 'Era para el ${diaMes(r.fecha)}',
                          alFinal: BotonCumplir(
                            tamano: 44,
                            onTap: () => cumplirAviso(context, ref, r),
                          ),
                        ),
                    ],
                  ),
                if (m.eliminados.isNotEmpty)
                  _Seccion(
                    titulo: 'Eliminados',
                    filas: [
                      for (final r in m.eliminados)
                        _Fila(
                          recordatorio: r,
                          apagada: true,
                          pie: r.eliminadoEl == null
                              ? 'Eliminado'
                              : 'Eliminado el ${diaMes(r.eliminadoEl!)}',
                          abajo: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  borrarParaSiempre(context, ref, r),
                              style: TextButton.styleFrom(
                                foregroundColor: Tono.vino,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('Borrar para siempre'),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.filas});

  final String titulo;
  final List<Widget> filas;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Espacio.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo.toUpperCase(), style: Tipo.etiqueta),
        const SizedBox(height: Espacio.xs),
        ...filas,
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.recordatorio,
    required this.pie,
    this.alFinal,
    this.abajo,
    this.apagada = false,
  });

  final Recordatorio recordatorio;
  final String pie;
  final Widget? alFinal;
  final Widget? abajo;
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    final detalle = clienteEquipoDe(recordatorio);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacio.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tituloDe(recordatorio),
                  style: Tipo.encabezado.copyWith(
                    color: apagada ? Tono.texto3 : Tono.texto,
                  ),
                ),
                if (detalle != null)
                  Text(
                    detalle,
                    style: Tipo.nota.copyWith(
                      color: apagada ? Tono.texto3 : Tono.texto2,
                    ),
                  ),
                Text(pie, style: Tipo.nota.copyWith(color: Tono.texto3)),
                ?abajo,
              ],
            ),
          ),
          if (alFinal != null) ...[const SizedBox(width: Espacio.md), alFinal!],
        ],
      ),
    );
  }
}
