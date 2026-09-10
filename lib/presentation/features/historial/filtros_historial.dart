import 'package:flutter/material.dart';

import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../domain/entities/trabajo.dart';
import '../../../domain/repositories/trabajos_repository.dart';

/// Los cuatro filtros del historial.
///
/// La búsqueda queda siempre visible; las fechas y el tipo se despliegan. En
/// el uso diario se busca por nombre nueve de cada diez veces, y cuatro
/// controles permanentes empujan la lista fuera de la pantalla.
class FiltrosHistorial extends StatefulWidget {
  const FiltrosHistorial({
    super.key,
    required this.filtro,
    required this.onCambio,
  });

  final FiltroHistorial filtro;
  final ValueChanged<FiltroHistorial> onCambio;

  @override
  State<FiltrosHistorial> createState() => _FiltrosHistorialState();
}

class _FiltrosHistorialState extends State<FiltrosHistorial> {
  final _busqueda = TextEditingController();
  bool _abierto = false;

  @override
  void initState() {
    super.initState();
    _busqueda.text = widget.filtro.busqueda;
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  bool get _hayFiltroExtra =>
      widget.filtro.desde.isNotEmpty ||
      widget.filtro.hasta.isNotEmpty ||
      widget.filtro.tipo != null;

  Future<void> _elegirFecha({required bool desde}) async {
    final actual = desde ? widget.filtro.desde : widget.filtro.hasta;

    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaDe(actual.isEmpty ? hoyISO() : actual),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (elegida == null) return;

    widget.onCambio(desde
        ? widget.filtro.copyWith(desde: isoDe(elegida))
        : widget.filtro.copyWith(hasta: isoDe(elegida)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busqueda,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    widget.onCambio(widget.filtro.copyWith(busqueda: v)),
                decoration: InputDecoration(
                  hintText: 'Buscar cliente o equipo',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: Tono.texto3),
                  suffixIcon: _busqueda.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _busqueda.clear();
                            widget.onCambio(
                                widget.filtro.copyWith(busqueda: ''));
                          },
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Tono.texto3),
                        ),
                ),
              ),
            ),
            const SizedBox(width: Espacio.sm),
            _BotonFiltros(
              activo: _hayFiltroExtra,
              abierto: _abierto,
              onTap: () => setState(() => _abierto = !_abierto),
            ),
          ],
        ),
        AnimatedSize(
          duration: duracion(context, Movimiento.normal),
          curve: Movimiento.muelle,
          alignment: Alignment.topCenter,
          child: _abierto
              ? Padding(
                  padding: const EdgeInsets.only(top: Espacio.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Fecha(
                              etiqueta: 'Desde',
                              valor: widget.filtro.desde,
                              onTap: () => _elegirFecha(desde: true),
                              onBorrar: () => widget
                                  .onCambio(widget.filtro.copyWith(desde: '')),
                            ),
                          ),
                          const SizedBox(width: Espacio.sm),
                          Expanded(
                            child: _Fecha(
                              etiqueta: 'Hasta',
                              valor: widget.filtro.hasta,
                              onTap: () => _elegirFecha(desde: false),
                              onBorrar: () => widget
                                  .onCambio(widget.filtro.copyWith(hasta: '')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Espacio.md),
                      Wrap(
                        spacing: Espacio.sm,
                        children: [
                          _Chip(
                            texto: 'Todos',
                            activo: widget.filtro.tipo == null,
                            onTap: () => widget.onCambio(
                                widget.filtro.copyWith(quitarTipo: true)),
                          ),
                          for (final tipo in TipoTrabajo.values)
                            _Chip(
                              texto: switch (tipo) {
                                TipoTrabajo.taller => 'Taller',
                                TipoTrabajo.campo => 'Campo',
                                TipoTrabajo.venta => 'Ventas',
                              },
                              activo: widget.filtro.tipo == tipo,
                              onTap: () => widget
                                  .onCambio(widget.filtro.copyWith(tipo: tipo)),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _BotonFiltros extends StatelessWidget {
  const _BotonFiltros({
    required this.activo,
    required this.abierto,
    required this.onTap,
  });

  final bool activo;
  final bool abierto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: kAreaTactil + 6,
            height: kAreaTactil + 6,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: abierto ? Tono.vinoSuave : Tono.fondo,
                side: BorderSide(
                    color: abierto ? Tono.vinoBorde : Tono.lineaFuerte),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: abierto ? Tono.vinoTexto : Tono.texto2,
              ),
            ),
          ),
          if (activo)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Tono.vino,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
}

class _Fecha extends StatelessWidget {
  const _Fecha({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
    required this.onBorrar,
  });

  final String etiqueta;
  final String valor;
  final VoidCallback onTap;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: Redondeo.brChico,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacio.md,
            vertical: Espacio.md,
          ),
          decoration: BoxDecoration(
            color: Tono.fondo,
            borderRadius: Redondeo.brChico,
            border: Border.all(color: Tono.linea),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiqueta.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      valor.isEmpty ? '—' : formatoCorto(valor),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (valor.isNotEmpty)
                InkWell(
                  onTap: onBorrar,
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Tono.texto3),
                ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(texto),
        selected: activo,
        showCheckmark: false,
        selectedColor: Tono.vinoSuave,
        side: BorderSide(color: activo ? Tono.vinoBorde : Tono.linea),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: activo ? Tono.vinoTexto : Tono.texto2,
        ),
        onSelected: (_) => onTap(),
      );
}
