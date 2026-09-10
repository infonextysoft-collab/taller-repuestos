import 'package:flutter/material.dart';

import '../../core/theme/movimiento.dart';
import '../../core/theme/tipografia.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/fechas.dart';
import '../../core/widgets/pulsable.dart';
import '../../domain/entities/repeticion.dart';

/// Cada cuánto se repite algo.
///
/// Reemplaza a los tres botones fijos —3, 6 y 12 meses— que había antes. Esa
/// lista era una suposición: hay mantenimientos cada 15 días y revisiones cada
/// 2 años, y ninguno de los dos entraba.
///
/// Quedan **atajos** para los tres casos más comunes, porque tocar un chip es
/// más rápido que armar el número, pero abajo está el intervalo libre para
/// todo lo demás. Y siempre se ve **la fecha que sale**: un intervalo sin la
/// fecha resultante obliga a hacer la cuenta de cabeza para saber si es lo que
/// se quería.
class SelectorRepeticion extends StatelessWidget {
  const SelectorRepeticion({
    super.key,
    required this.valor,
    required this.onCambio,
    required this.desde,
    this.bloqueado = false,
  });

  /// `null` = no se repite.
  final Repeticion? valor;
  final ValueChanged<Repeticion?> onCambio;

  /// Desde qué fecha se cuenta el próximo, para la vista previa.
  final String desde;

  final bool bloqueado;

  static const List<Repeticion> _atajos = [
    Repeticion(15, UnidadRepeticion.dias),
    Repeticion(3, UnidadRepeticion.meses),
    Repeticion(6, UnidadRepeticion.meses),
    Repeticion(1, UnidadRepeticion.anios),
  ];

  void _cambiarCantidad(int delta) {
    final actual = valor ?? const Repeticion(1, UnidadRepeticion.meses);
    final siguiente = (actual.cada + delta).clamp(1, 99);
    onCambio(Repeticion(siguiente, actual.unidad));
  }

  @override
  Widget build(BuildContext context) {
    final repite = valor != null && valor!.valida;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Espacio.sm,
          runSpacing: Espacio.sm,
          children: [
            _Chip(
              texto: 'No se repite',
              activo: !repite,
              onTap: bloqueado ? null : () => onCambio(null),
            ),
            for (final atajo in _atajos)
              _Chip(
                texto: atajo.etiqueta,
                activo: repite && valor == atajo,
                onTap: bloqueado ? null : () => onCambio(atajo),
              ),
          ],
        ),
        AnimatedSize(
          duration: duracion(context, Movimiento.normal),
          curve: Movimiento.muelle,
          alignment: Alignment.topCenter,
          child: !repite
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Espacio.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Intervalo(
                        valor: valor!,
                        bloqueado: bloqueado,
                        onCantidad: _cambiarCantidad,
                        onUnidad: (u) =>
                            onCambio(Repeticion(valor!.cada, u)),
                      ),
                      const SizedBox(height: Espacio.md),
                      Row(
                        children: [
                          const Icon(Icons.event_repeat_rounded,
                              size: 15, color: Tono.oroTexto),
                          const SizedBox(width: Espacio.sm),
                          Expanded(
                            child: Text(
                              'El próximo cae el '
                              '${formatoLargo(valor!.siguiente(desde))}.',
                              style: Tipo.nota.copyWith(color: Tono.oroTexto),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// El intervalo libre: cuánto, y de qué.
class _Intervalo extends StatelessWidget {
  const _Intervalo({
    required this.valor,
    required this.bloqueado,
    required this.onCantidad,
    required this.onUnidad,
  });

  final Repeticion valor;
  final bool bloqueado;
  final ValueChanged<int> onCantidad;
  final ValueChanged<UnidadRepeticion> onUnidad;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Cada', style: Tipo.secundario),
              const SizedBox(width: Espacio.md),
              _Paso(
                icono: Icons.remove_rounded,
                habilitado: !bloqueado && valor.cada > 1,
                onTap: () => onCantidad(-1),
              ),
              SizedBox(
                width: 54,
                child: Center(
                  child: Text(
                    '${valor.cada}',
                    style: Tipo.titulo2.copyWith(
                      fontFeatures: kNumerosTabulares,
                    ),
                  ),
                ),
              ),
              _Paso(
                icono: Icons.add_rounded,
                habilitado: !bloqueado && valor.cada < 99,
                onTap: () => onCantidad(1),
              ),
            ],
          ),
          const SizedBox(height: Espacio.md),
          Row(
            children: [
              for (final u in UnidadRepeticion.values) ...[
                Expanded(
                  child: _Unidad(
                    texto: valor.cada == 1 ? u.singular : u.plural,
                    activo: valor.unidad == u,
                    onTap: bloqueado ? null : () => onUnidad(u),
                  ),
                ),
                if (u != UnidadRepeticion.values.last)
                  const SizedBox(width: Espacio.sm),
              ],
            ],
          ),
        ],
      );
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.icono,
    required this.habilitado,
    required this.onTap,
  });

  final IconData icono;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: habilitado ? onTap : null,
        escala: 0.9,
        child: Container(
          width: kAreaTactil,
          height: kAreaTactil,
          decoration: BoxDecoration(
            color: Tono.fondo,
            borderRadius: Redondeo.brChico,
            border: Border.all(color: Tono.linea),
          ),
          child: Icon(
            icono,
            size: 20,
            color: habilitado ? Tono.texto : Tono.texto3,
          ),
        ),
      );
}

class _Unidad extends StatelessWidget {
  const _Unidad({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.96,
        child: Container(
          height: kAreaTactil,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Tono.vino : Tono.fondo,
            borderRadius: Redondeo.brChico,
            border: Border.all(color: activo ? Tono.vino : Tono.linea),
          ),
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tipo.nota.copyWith(
              fontSize: 13,
              color: activo ? Tono.textoInverso : Tono.texto2,
            ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.96,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacio.md + 2,
            vertical: Espacio.sm + 2,
          ),
          decoration: BoxDecoration(
            color: activo ? Tono.vino : Tono.fondo,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: activo ? Tono.vino : Tono.linea),
          ),
          child: Text(
            texto,
            style: Tipo.nota.copyWith(
              fontSize: 13,
              color: activo ? Tono.textoInverso : Tono.texto2,
            ),
          ),
        ),
      );
}
