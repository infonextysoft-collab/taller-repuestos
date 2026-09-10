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
  });

  final T valor;
  final List<OpcionChip<T>> opciones;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: opciones.length,
          separatorBuilder: (_, _) => const SizedBox(width: Espacio.sm),
          itemBuilder: (context, i) {
            final o = opciones[i];
            final activo = o.valor == valor;

            return GestureDetector(
              onTap: () => onCambio(o.valor),
              child: AnimatedContainer(
                duration: duracion(context, Movimiento.micro),
                curve: Movimiento.salida,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
                decoration: BoxDecoration(
                  color: activo ? Tono.vino : Tono.fondo,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
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
          },
        ),
      );
}
