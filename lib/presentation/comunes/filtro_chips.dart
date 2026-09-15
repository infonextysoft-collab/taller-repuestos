import 'package:flutter/material.dart';

import '../../core/theme/movimiento.dart';
import '../../core/theme/tokens.dart';

/// Una opción de [FiltroChips], con su contador.
class OpcionChip<T> {
  const OpcionChip(this.valor, this.texto, [this.cantidad]);

  final T valor;
  final String texto;

  /// Cuántos hay. Se muestra al lado del nombre: saber que "Agotados" tiene 0
  /// evita tocarlo para descubrir que no hay nada.
  final int? cantidad;
}

/// Fila de filtros excluyentes.
///
/// Se usa el mismo control en todas las listas: si en una pantalla los filtros
/// son chips y en otra un desplegable, cada lista se vuelve una interfaz
/// distinta que hay que aprender de nuevo.
class FiltroChips<T> extends StatelessWidget {
  const FiltroChips({
    super.key,
    required this.valor,
    required this.opciones,
    required this.onCambio,
    this.compactos = false,
  });

  final T valor;
  final List<OpcionChip<T>> opciones;
  final ValueChanged<T> onCambio;

  /// Para cuando la fila comparte el ancho con un botón y las opciones son
  /// pocas: menos aire a los lados y, en vez de desplazarse, **se achica lo
  /// justo para entrar entera**.
  ///
  /// Desplazarse sirve con seis vistas, no con tres: en un teléfono de 360
  /// puntos con contadores de dos cifras, el último chip quedaba cortado
  /// debajo del botón, y "Agotados" es justo el que más se busca. Achicarse
  /// ahí es un 5 %, que no se nota; y con letra grande de accesibilidad sigue
  /// entrando todo en vez de esconder una opción.
  final bool compactos;

  @override
  Widget build(BuildContext context) {
    if (compactos) {
      return SizedBox(
        height: 38,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < opciones.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                SizedBox(height: 38, child: _chip(context, opciones[i])),
              ],
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: Espacio.sm),
        itemBuilder: (context, i) => _chip(context, opciones[i]),
      ),
    );
  }

  Widget _chip(BuildContext context, OpcionChip<T> o) {
    final activo = o.valor == valor;

    return GestureDetector(
      onTap: () => onCambio(o.valor),
      child: AnimatedContainer(
        duration: duracion(context, Movimiento.micro),
        curve: Movimiento.salida,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compactos ? 10 : Espacio.lg,
        ),
        decoration: BoxDecoration(
          color: activo ? Tono.vino : Tono.fondo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              o.texto,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : Tono.texto2,
              ),
            ),
            if (o.cantidad != null) ...[
              const SizedBox(width: 6),
              Text(
                '${o.cantidad}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kNumerosTabulares,
                  color: activo ? Tono.oroClaro : Tono.texto3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
