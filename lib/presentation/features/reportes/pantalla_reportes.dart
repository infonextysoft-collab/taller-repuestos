import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/texto.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/compra.dart';
import '../../../domain/entities/trabajo.dart';
import '../../../domain/services/estadisticas.dart';
import '../../../domain/services/ganancia.dart';
import '../../comunes/filtro_chips.dart';

enum _Periodo { mes, anio, todo }

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
  _Periodo _periodo = _Periodo.mes;
  List<Trabajo> _trabajos = const [];
  List<Compra> _compras = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final trabajos = await ref.read(trabajosRepoProvider).listar();
    final compras = await ref.read(comprasRepoProvider).listar();

    if (mounted) {
      setState(() {
        _trabajos = trabajos;
        _compras = compras;
        _cargando = false;
      });
    }
  }

  bool _entra(String fecha) => switch (_periodo) {
        _Periodo.mes => fecha.startsWith(claveMes(hoyISO())),
        _Periodo.anio => fecha.startsWith(hoyISO().substring(0, 4)),
        _Periodo.todo => true,
      };

  /// Solo los trabajos cerrados: uno a medias todavía no es plata.
  List<Trabajo> get _cerrados =>
      _trabajos.where((t) => t.estaTerminado && _entra(t.fecha)).toList();

  List<Compra> get _comprasDelPeriodo =>
      _compras.where((c) => _entra(c.fecha)).toList();

  @override
  Widget build(BuildContext context) {
    final cerrados = _cerrados;
    final compras = _comprasDelPeriodo;

    var cobrado = 0.0;
    var costo = 0.0;
    var sinCosto = 0;
    for (final t in cerrados) {
      final g = gananciaDe(t);
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
              child: FiltroChips<_Periodo>(
                valor: _periodo,
                opciones: const [
                  OpcionChip(_Periodo.mes, 'Este mes'),
                  OpcionChip(_Periodo.anio, 'Este año'),
                  OpcionChip(_Periodo.todo, 'Todo'),
                ],
                onCambio: (p) => setState(() => _periodo = p),
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
                  comprado: redondear(
                    compras.fold<double>(0, (s, c) => s + c.total),
                  ),
                  compras: compras.length,
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
              const SizedBox(height: Espacio.xl),
              Contenido(
                ancho: Ancho.acciones,
                child: _PorProveedor(compras: compras),
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
    required this.comprado,
    required this.compras,
  });

  final int trabajos;
  final double cobrado;
  final double costo;
  final int sinCosto;
  final double comprado;
  final int compras;

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
          const SizedBox(height: Espacio.sm),
          _Dato(
            compras == 1 ? 'Comprado en 1 compra' : 'Comprado en $compras compras',
            soles(comprado),
            apagado: true,
          ),
          const SizedBox(height: Espacio.sm),
          Text(
            'Lo comprado no se resta de la ganancia: lo que entra al stock se '
            'descuenta recién cuando se vende.',
            style: Tipo.nota,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.apagado = false});

  final String etiqueta;
  final String valor;
  final bool apagado;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Espacio.sm),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: Tipo.secundario)),
            const SizedBox(width: Espacio.md),
            Text(
              valor,
              style: Tipo.monto.copyWith(
                color: apagado ? Tono.texto3 : Tono.texto,
              ),
            ),
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
                  v.nombre,
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
                v.completa ? 'deja ${soles(v.ganancia)}' : 'sin costo',
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

/// A quién se le compró más en el período.
class _PorProveedor extends StatelessWidget {
  const _PorProveedor({required this.compras});

  final List<Compra> compras;

  @override
  Widget build(BuildContext context) {
    // Se agrupa ignorando tildes y mayúsculas, igual que al sugerirlos.
    final total = <String, double>{};
    final nombres = <String, String>{};

    for (final c in compras) {
      final quien = c.proveedor.trim();
      final clave = quien.isEmpty ? '' : normalizar(quien);
      total[clave] = (total[clave] ?? 0) + c.total;
      nombres.putIfAbsent(clave, () => quien.isEmpty ? 'Sin proveedor' : quien);
    }

    final claves = total.keys.toList()
      ..sort((a, b) => total[b]!.compareTo(total[a]!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('A QUIÉN LE COMPRAS', style: Tipo.etiqueta),
        const SizedBox(height: Espacio.md),
        if (claves.isEmpty)
          Panel(
            color: Tono.fondo2,
            child: Text(
              'No hay compras registradas en este período.',
              style: Tipo.secundario,
            ),
          )
        else
          ListaAgrupada(
            filas: [
              for (final clave in claves.take(5))
                FilaLista(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombres[clave]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: clave.isEmpty
                              ? Tipo.encabezado.copyWith(color: Tono.texto3)
                              : Tipo.encabezado,
                        ),
                      ),
                      Text(soles(redondear(total[clave]!)), style: Tipo.monto),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
