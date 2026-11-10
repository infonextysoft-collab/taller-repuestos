import 'package:flutter/material.dart';

import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/hoja.dart';

enum PeriodoReporte { mes, anio, todo, rango }

/// Qué trabajos entran en los números de Reportes.
///
/// Los tres períodos de siempre resuelven casi todo, y el rango está para lo
/// que no: cerrar una quincena, mirar lo que dejó una semana. Van juntos en
/// **un solo control** y no en tres chips más dos fechas sueltas, que era
/// cinco cosas para elegir una.
class FiltroReporte {
  const FiltroReporte({
    this.periodo = PeriodoReporte.mes,
    this.desde = '',
    this.hasta = '',
  });

  final PeriodoReporte periodo;

  /// Solo cuentan con [PeriodoReporte.rango]. Vacío = sin tope de ese lado.
  final String desde;
  final String hasta;

  FiltroReporte copyWith({
    PeriodoReporte? periodo,
    String? desde,
    String? hasta,
  }) =>
      FiltroReporte(
        periodo: periodo ?? this.periodo,
        desde: desde ?? this.desde,
        hasta: hasta ?? this.hasta,
      );

  bool entra(String fecha) => switch (periodo) {
        PeriodoReporte.mes => fecha.startsWith(claveMes(hoyISO())),
        PeriodoReporte.anio => fecha.startsWith(hoyISO().substring(0, 4)),
        PeriodoReporte.todo => true,
        // Las dos puntas van incluidas: quien elige "del 1 al 15" cuenta el 15.
        PeriodoReporte.rango => (desde.isEmpty || fecha.compareTo(desde) >= 0) &&
            (hasta.isEmpty || fecha.compareTo(hasta) <= 0),
      };

  /// Cómo se llama este período en el botón.
  String get etiqueta => switch (periodo) {
        PeriodoReporte.mes => nombreMes(claveMes(hoyISO())),
        PeriodoReporte.anio => hoyISO().substring(0, 4),
        PeriodoReporte.todo => 'Todo',
        PeriodoReporte.rango => switch ((desde.isEmpty, hasta.isEmpty)) {
            (true, true) => 'Todo',
            (false, true) => 'Desde ${formatoCorto(desde)}',
            (true, false) => 'Hasta ${formatoCorto(hasta)}',
            _ => '${formatoCorto(desde)} – ${formatoCorto(hasta)}',
          },
      };
}

/// El botón que abre los filtros y muestra cuál está puesto.
class BotonFiltroReporte extends StatelessWidget {
  const BotonFiltroReporte({
    super.key,
    required this.filtro,
    required this.onCambio,
  });

  final FiltroReporte filtro;
  final ValueChanged<FiltroReporte> onCambio;

  Future<void> _abrir(BuildContext context) async {
    final elegido = await mostrarHoja<FiltroReporte>(
      context,
      titulo: 'Qué período mirar',
      contenido: (hoja) => _Opciones(
        filtro: filtro,
        onListo: (f) => Navigator.of(hoja).pop(f),
      ),
    );
    if (elegido != null) onCambio(elegido);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () => _abrir(context),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 19, color: Tono.vino),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Text(
                filtro.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 20, color: Tono.texto3),
          ],
        ),
      );
}

class _Opciones extends StatefulWidget {
  const _Opciones({required this.filtro, required this.onListo});

  final FiltroReporte filtro;
  final ValueChanged<FiltroReporte> onListo;

  @override
  State<_Opciones> createState() => _OpcionesState();
}

class _OpcionesState extends State<_Opciones> {
  late FiltroReporte _filtro = widget.filtro;

  Future<void> _elegirFecha({required bool desde}) async {
    final actual = desde ? _filtro.desde : _filtro.hasta;

    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaDe(actual.isEmpty ? hoyISO() : actual),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (elegida == null) return;

    setState(() {
      _filtro = desde
          ? _filtro.copyWith(
              periodo: PeriodoReporte.rango, desde: isoDe(elegida))
          : _filtro.copyWith(
              periodo: PeriodoReporte.rango, hasta: isoDe(elegida));
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.xl,
          0,
          Espacio.xl,
          Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in const [
              (PeriodoReporte.mes, 'Este mes'),
              (PeriodoReporte.anio, 'Este año'),
              (PeriodoReporte.todo, 'Todo'),
            ])
              _Opcion(
                texto: p.$2,
                elegido: _filtro.periodo == p.$1,
                onTap: () => widget.onListo(FiltroReporte(periodo: p.$1)),
              ),
            const Divider(height: Espacio.xl, color: Tono.linea),
            Text('ENTRE DOS FECHAS', style: Tipo.etiqueta),
            const SizedBox(height: Espacio.md),
            Row(
              children: [
                Expanded(
                  child: _Fecha(
                    rotulo: 'Desde',
                    valor: _filtro.desde,
                    onTap: () => _elegirFecha(desde: true),
                  ),
                ),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: _Fecha(
                    rotulo: 'Hasta',
                    valor: _filtro.hasta,
                    onTap: () => _elegirFecha(desde: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.lg),
            FilledButton(
              onPressed: _filtro.desde.isEmpty && _filtro.hasta.isEmpty
                  ? null
                  : () => widget.onListo(
                        _filtro.copyWith(periodo: PeriodoReporte.rango),
                      ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      );
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.texto,
    required this.elegido,
    required this.onTap,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: Redondeo.brChico,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Espacio.md),
          child: Row(
            children: [
              Icon(
                elegido
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: elegido ? Tono.vino : Tono.texto3,
              ),
              const SizedBox(width: Espacio.md),
              Text(
                texto,
                style: Tipo.cuerpo.copyWith(
                  fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Fecha extends StatelessWidget {
  const _Fecha({required this.rotulo, required this.valor, required this.onTap});

  final String rotulo;
  final String valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.md),
        ),
        child: Text(
          valor.isEmpty ? rotulo : formatoCorto(valor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tipo.cuerpo.copyWith(
            color: valor.isEmpty ? Tono.texto3 : Tono.texto,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
