import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/trabajo.dart';
import '../../../domain/services/estadisticas.dart';
import '../../../domain/services/ganancia.dart';
import 'filtro_reportes.dart';

/// Los números del taller: cuánto entró, cuánto costó y qué se vende más.
///
/// Se calcula **al abrir la pantalla**, no todo el tiempo: hay que recorrer
/// los trabajos uno por uno, y eso no puede pasar en cada pantallazo de la
/// lista. Por eso vive acá y no en las tarjetas del Historial, que se rearman
/// seguido y son para lo urgente, no para lo analítico.
class PantallaReportes extends ConsumerStatefulWidget {
  const PantallaReportes({super.key});

  @override
  ConsumerState<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends ConsumerState<PantallaReportes> {
  FiltroReporte _filtro = const FiltroReporte();
  List<Trabajo> _trabajos = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final trabajos = await ref.read(trabajosRepoProvider).listar();

    if (mounted) {
      setState(() {
        _trabajos = trabajos;
        _cargando = false;
      });
    }
  }

  /// Solo los trabajos cerrados: uno a medias todavía no es plata.
  List<Trabajo> get _cerrados => _trabajos
      .where((t) => t.estaTerminado && _filtro.entra(t.fecha))
      .toList();

  @override
  Widget build(BuildContext context) {
    final cerrados = _cerrados;

    var mano = 0.0;
    var repuestos = 0.0;
    var cobrado = 0.0;
    var costo = 0.0;
    var sinCosto = 0;

    for (final t in cerrados) {
      final g = gananciaDe(t);
      mano += g.netaMano;
      repuestos += g.netaRepuestos;
      cobrado += g.cobrado;
      costo += g.costo;
      sinCosto += g.sinCosto;
    }

    final masVendidos = ventasPorRepuesto(cerrados).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: RefreshIndicator(
        color: Tono.vino,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
          children: [
            Contenido(
              ancho: Ancho.acciones,
              child: BotonFiltroReporte(
                filtro: _filtro,
                onCambio: (f) => setState(() => _filtro = f),
              ),
            ),
            const SizedBox(height: Espacio.lg),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: Espacio.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Contenido(
                ancho: Ancho.acciones,
                child: _Plata(
                  trabajos: cerrados.length,
                  cobrado: redondear(cobrado),
                  costo: redondear(costo),
                  sinCosto: sinCosto,
                ),
              ),
              const SizedBox(height: Espacio.md),
              // De dónde salió esa ganancia: de tu tiempo o de tus piezas.
              // Son dos negocios distintos metidos en el mismo taller, y
              // sumados en un solo número no se sabe cuál está andando.
              Contenido(
                ancho: Ancho.acciones,
                // Las dos del mismo alto aunque una tenga una línea más de
                // texto: dos tarjetas desparejas lado a lado se leen como si
                // una importara más que la otra.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Mitad(
                          titulo: 'MANO DE OBRA',
                          icono: Icons.handyman_rounded,
                          monto: redondear(mano),
                          detalle: 'Lo que cobras por trabajar no tiene costo '
                              'de repuestos.',
                        ),
                      ),
                      const SizedBox(width: Espacio.md),
                      Expanded(
                        child: _Mitad(
                          titulo: 'INVENTARIO',
                          icono: Icons.inventory_2_rounded,
                          monto: redondear(repuestos),
                          detalle: sinCosto > 0
                              ? 'Es un techo: faltan costos.'
                              : 'Lo vendido menos lo que costó reponerlo.',
                          incompleto: sinCosto > 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Espacio.xl),
              Contenido(
                ancho: Ancho.acciones,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('LO QUE MÁS SALE', style: Tipo.etiqueta),
                    const SizedBox(height: Espacio.md),
                    if (masVendidos.isEmpty)
                      Panel(
                        color: Tono.fondo2,
                        child: Text(
                          'No hay repuestos vendidos en este período.',
                          style: Tipo.secundario,
                        ),
                      )
                    else
                      ListaAgrupada(
                        filas: [
                          for (final v in masVendidos) _FilaVendido(ventas: v),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lo que entró, lo que costó y lo que quedó.
class _Plata extends StatelessWidget {
  const _Plata({
    required this.trabajos,
    required this.cobrado,
    required this.costo,
    required this.sinCosto,
  });

  final int trabajos;
  final double cobrado;
  final double costo;
  final int sinCosto;

  @override
  Widget build(BuildContext context) {
    final ganancia = redondear(cobrado - costo);

    return Panel(
      color: Tono.fondo2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sinCosto == 0 ? 'GANANCIA' : 'GANANCIA, COMO MUCHO',
            style: Tipo.etiqueta,
          ),
          const SizedBox(height: Espacio.sm),
          Text(
            soles(ganancia),
            style: Tipo.display.copyWith(
              fontSize: 34,
              color: ganancia < 0 ? Tono.vino : Tono.oroTexto,
            ),
          ),
          if (sinCosto > 0) ...[
            const SizedBox(height: Espacio.xs),
            Text(
              sinCosto == 1
                  ? 'Hay 1 repuesto sin costo registrado.'
                  : 'Hay $sinCosto repuestos sin costo registrado.',
              style: Tipo.nota,
            ),
          ],
          const Divider(height: Espacio.xl, color: Tono.linea),
          _Dato(
            trabajos == 1 ? 'Cobrado en 1 trabajo' : 'Cobrado en $trabajos trabajos',
            soles(cobrado),
          ),
          _Dato('Costo de los repuestos usados', soles(costo)),
        ],
      ),
    );
  }
}

/// Una de las dos mitades de la ganancia.
class _Mitad extends StatelessWidget {
  const _Mitad({
    required this.titulo,
    required this.icono,
    required this.monto,
    required this.detalle,
    this.incompleto = false,
  });

  final String titulo;
  final IconData icono;
  final double monto;
  final String detalle;
  final bool incompleto;

  @override
  Widget build(BuildContext context) => Panel(
        color: Tono.fondo2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 16, color: Tono.texto3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.etiqueta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                soles(monto),
                style: Tipo.display.copyWith(
                  fontSize: 23,
                  color: monto < 0 ? Tono.vino : Tono.oroTexto,
                ),
              ),
            ),
            const SizedBox(height: Espacio.xs),
            Text(
              detalle,
              style: Tipo.nota.copyWith(
                color: incompleto ? Tono.vinoTexto : Tono.texto3,
              ),
            ),
          ],
        ),
      );
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Espacio.sm),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: Tipo.secundario)),
            const SizedBox(width: Espacio.md),
            Text(valor, style: Tipo.monto),
          ],
        ),
      );
}

class _FilaVendido extends StatelessWidget {
  const _FilaVendido({required this.ventas});

  final VentasDeRepuesto ventas;

  @override
  Widget build(BuildContext context) {
    final v = ventas;

    return FilaLista(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.nombre.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tipo.encabezado,
                ),
                const SizedBox(height: 3),
                Text(
                  v.unidades == 1 ? '1 unidad' : '${v.unidades} unidades',
                  style: Tipo.nota,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(soles(v.cobrado), style: Tipo.monto),
              const SizedBox(height: 3),
              Text(
                v.completa ? 'gana ${soles(v.ganancia)}' : 'sin costo',
                style: Tipo.nota.copyWith(
                  color: v.completa ? Tono.oroTexto : Tono.texto3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
