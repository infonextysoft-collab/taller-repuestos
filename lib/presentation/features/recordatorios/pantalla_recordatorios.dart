import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/pulsable.dart';
import '../../../domain/entities/recordatorio.dart';
import '../../../domain/services/historial_avisos.dart';
import '../shell/barra_inferior.dart';
import 'acciones_aviso.dart';
import 'pantalla_completados.dart';
import 'pantalla_programados.dart';
import 'tarjeta_aviso.dart';

/// Las dos fichas que muestran su lista debajo, sin cambiar de pantalla.
enum _Vista { vencidos, hoy }

/// Avisos: cuatro fichas grandes arriba y, debajo, lo que hay que atender.
///
/// Vencidos y Hoy se ven acá mismo porque son lo que se viene a resolver.
/// Programados y Completados son para consultar: abren su propia pantalla, y
/// la flechita de la ficha lo anuncia.
class PantallaRecordatorios extends ConsumerStatefulWidget {
  const PantallaRecordatorios({super.key});

  @override
  ConsumerState<PantallaRecordatorios> createState() =>
      _PantallaRecordatoriosState();
}

class _PantallaRecordatoriosState extends ConsumerState<PantallaRecordatorios> {
  List<Recordatorio> _todos = const [];

  /// `null` hasta que se toque una ficha: mientras tanto se elige sola.
  _Vista? _elegida;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = ref.read(recordatoriosRepoProvider);
    // La app puede quedar abierta de un día para otro.
    final recienVencidos = await repo.refrescarVencidos();
    final items = await repo.listar();

    if (!mounted) return;
    if (recienVencidos > 0) ref.invalidate(vencidosProvider);

    setState(() {
      _todos = items;
      _cargando = false;
      // Al resolver el último de la lista elegida, vuelve a elegirse sola.
      final elegida = _elegida;
      if (elegida != null && _lista(elegida).isEmpty) _elegida = null;
    });
  }

  List<Recordatorio> _lista(_Vista v) {
    final hoy = hoyISO();
    return _todos.where((r) {
      if (!r.activo) return false;
      final comparacion = r.fecha.compareTo(hoy);
      return v == _Vista.vencidos ? comparacion < 0 : comparacion == 0;
    }).toList();
  }

  List<Recordatorio> get _programados {
    final hoy = hoyISO();
    return _todos.where((r) => r.activo && r.fecha.compareTo(hoy) > 0).toList();
  }

  void _abrir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoRecordatoriosProvider, (_, _) => _cargar());

    final vencidos = _lista(_Vista.vencidos);
    final deHoy = _lista(_Vista.hoy);
    final vista =
        _elegida ?? (vencidos.isNotEmpty ? _Vista.vencidos : _Vista.hoy);
    final visibles = vista == _Vista.vencidos ? vencidos : deHoy;
    final anio = fechaDe(hoyISO()).year;

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
              Espacio.md,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Mis avisos', style: Tipo.titulo2)),
                SizedBox(
                  width: kAreaTactil,
                  height: kAreaTactil,
                  child: Tooltip(
                    message: 'Nuevo aviso',
                    child: OutlinedButton(
                      onPressed: () => nuevoAviso(context, ref),
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
          ),
          Contenido(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Ficha(
                        titulo: 'Vencidos',
                        cantidad: vencidos.length,
                        icono: Icons.error_outline_rounded,
                        color: vencidos.isEmpty ? Tono.texto2 : Tono.vino,
                        fondoIcono: vencidos.isEmpty ? Tono.fondo2 : Tono.fondo,
                        alerta: vencidos.isNotEmpty,
                        seleccionada: vista == _Vista.vencidos,
                        onTap: () => setState(() => _elegida = _Vista.vencidos),
                      ),
                    ),
                    const SizedBox(width: Espacio.md),
                    Expanded(
                      child: _Ficha(
                        titulo: 'Hoy',
                        cantidad: deHoy.length,
                        icono: Icons.today_rounded,
                        color: Tono.oro,
                        fondoIcono: Tono.oroSuave,
                        seleccionada: vista == _Vista.hoy,
                        onTap: () => setState(() => _elegida = _Vista.hoy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacio.md),
                Row(
                  children: [
                    Expanded(
                      child: _Ficha(
                        titulo: 'Programados',
                        cantidad: _programados.length,
                        icono: Icons.event_rounded,
                        color: Tono.texto2,
                        fondoIcono: Tono.fondo2,
                        abrePantalla: true,
                        onTap: () => _abrir(const PantallaProgramados()),
                      ),
                    ),
                    const SizedBox(width: Espacio.md),
                    Expanded(
                      child: _Ficha(
                        titulo: 'Completados',
                        cantidad: cumplidosDelAnio(_todos, anio),
                        icono: Icons.check_circle_outline_rounded,
                        color: Tono.texto2,
                        fondoIcono: Tono.fondo2,
                        abrePantalla: true,
                        onTap: () => _abrir(const PantallaCompletados()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Espacio.xl),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.only(top: Espacio.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibles.isEmpty)
            Contenido(
              child: Panel(
                child: Text(
                  vista == _Vista.vencidos
                      ? 'No tienes avisos vencidos.'
                      : 'Nada para hoy. Todo al día.',
                  style: Tipo.secundario,
                ),
              ),
            )
          else
            for (final r in visibles)
              Contenido(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.lg,
                  0,
                  Espacio.lg,
                  Espacio.md,
                ),
                child: TarjetaAviso(
                  recordatorio: r,
                  onTap: () => abrirAviso(context, ref, r),
                  onCumplir: () => cumplirAviso(context, ref, r),
                ),
              ),
        ],
      ),
    );
  }
}

/// Una ficha grande: ícono redondo, número y nombre.
///
/// El borde va siempre, transparente cuando no toca, para que el contenido no
/// salte ni un punto al elegirla.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.titulo,
    required this.cantidad,
    required this.icono,
    required this.color,
    required this.fondoIcono,
    required this.onTap,
    this.alerta = false,
    this.seleccionada = false,
    this.abrePantalla = false,
  });

  final String titulo;
  final int cantidad;
  final IconData icono;
  final Color color;
  final Color fondoIcono;
  final VoidCallback onTap;
  final bool alerta;
  final bool seleccionada;
  final bool abrePantalla;

  @override
  Widget build(BuildContext context) => Pulsable(
    onTap: onTap,
    escala: 0.97,
    semantica: '$titulo, $cantidad',
    child: AnimatedContainer(
      duration: duracion(context, Movimiento.micro),
      curve: Movimiento.salida,
      padding: const EdgeInsets.all(Espacio.lg),
      decoration: BoxDecoration(
        color: alerta ? Tono.vinoSuave : Tono.fondo,
        borderRadius: Redondeo.brNormal,
        border: Border.all(
          width: 2,
          color: seleccionada
              ? Tono.negro
              : alerta
              ? Tono.vinoBorde
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 23, color: color),
              ),
              const Spacer(),
              if (abrePantalla)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: Tono.texto3,
                ),
            ],
          ),
          const SizedBox(height: Espacio.md),
          Text(
            '$cantidad',
            style: Tipo.titulo1.copyWith(
              fontSize: 34,
              height: 1.05,
              fontFeatures: kNumerosTabulares,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tipo.encabezado.copyWith(fontSize: 15),
          ),
        ],
      ),
    ),
  );
}
