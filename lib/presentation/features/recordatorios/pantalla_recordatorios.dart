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
                        icono: Icons.warning_amber_rounded,
                        color: vencidos.isEmpty ? Tono.texto2 : Tono.vino,
                        alerta: vencidos.isNotEmpty,
                        seleccionada: vista == _Vista.vencidos,
                        onTap: () => setState(() => _elegida = _Vista.vencidos),
                      ),
                    ),
                    const SizedBox(width: Espacio.sm),
                    Expanded(
                      child: _Ficha(
                        titulo: 'Hoy',
                        cantidad: deHoy.length,
                        icono: Icons.calendar_today_outlined,
                        color: Tono.texto2,
                        seleccionada: vista == _Vista.hoy,
                        onTap: () => setState(() => _elegida = _Vista.hoy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacio.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Ficha(
                        titulo: 'Programados',
                        cantidad: _programados.length,
                        icono: Icons.schedule_rounded,
                        color: Tono.texto2,
                        onTap: () => _abrir(const PantallaProgramados()),
                      ),
                    ),
                    const SizedBox(width: Espacio.sm),
                    Expanded(
                      child: _Ficha(
                        titulo: 'Completados',
                        cantidad: cumplidosDelAnio(_todos, anio),
                        icono: Icons.check_circle_outline_rounded,
                        color: Tono.oro,
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

/// El rosado de la ficha de vencidos: más cargado que el suave de las
/// insignias, para que se vea desde lejos aunque no sea la elegida.
const Color _rosaVencido = Color(0xFFF8E0DE);
const Color _bordeVencido = Color(0xFFD98880);

/// Fondo de la ficha elegida, cuando no es la de vencidos.
const Color _fondoElegida = Color(0xFFEDE8DE);

/// Una ficha: ícono chico arriba, número a la derecha y nombre abajo.
///
/// Vencidos va siempre en rojo cuando tiene algo, esté elegida o no: es lo
/// primero que hay que ver, y no puede parecerse a la de Hoy. La elegida se
/// marca con un borde oscuro; en vencidos, el rojo se vuelve más fuerte.
///
/// El borde tiene siempre el mismo grosor, para que nada se mueva al elegir.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.titulo,
    required this.cantidad,
    required this.icono,
    required this.color,
    required this.onTap,
    this.alerta = false,
    this.seleccionada = false,
  });

  final String titulo;
  final int cantidad;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  final bool alerta;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final (fondo, borde) = alerta
        ? (_rosaVencido, seleccionada ? Tono.vino : _bordeVencido)
        : seleccionada
        ? (_fondoElegida, Tono.negro)
        : (Tono.fondo, Tono.lineaFuerte);

    return Pulsable(
      onTap: onTap,
      escala: 0.97,
      semantica: '$titulo, $cantidad',
      child: AnimatedContainer(
        duration: duracion(context, Movimiento.micro),
        curve: Movimiento.salida,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: Redondeo.brNormal,
          border: Border.all(width: 1.5, color: borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: alerta ? const Color(0xFFF2C9C5) : Tono.fondo2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, size: 18, color: color),
                ),
                const Spacer(),
                Text(
                  '$cantidad',
                  style: Tipo.titulo1.copyWith(
                    fontSize: 26,
                    height: 1,
                    fontFeatures: kNumerosTabulares,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.md),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tipo.encabezado.copyWith(fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }
}
