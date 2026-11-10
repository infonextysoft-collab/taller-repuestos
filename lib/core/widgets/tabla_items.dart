import 'package:flutter/material.dart';

import '../../domain/entities/linea.dart';
import '../theme/tipografia.dart';
import '../theme/tokens.dart';
import '../utils/dinero.dart';
import 'contenido.dart';
import 'pulsable.dart';

/// Las líneas ya cargadas de un registro.
///
/// Van en **una sola superficie** con separadores, no una tarjeta por línea:
/// con seis repuestos, seis tarjetas con borde y sombra convierten la pantalla
/// en una pila de cajas.
///
/// La cantidad se muestra solo cuando significa algo —la mano de obra no la
/// lleva— y cuando se puede editar se edita acá mismo con − y +, en vez de
/// borrar la línea y volver a cargarla.
class TablaItems extends StatelessWidget {
  const TablaItems({
    super.key,
    required this.items,
    this.vacio = 'Todavía no agregaste nada.',
    this.mostrarCantidad = true,
    this.mostrarOrigen = false,
    this.onEliminar,
    this.onCambiarCantidad,
  });

  final List<LineaDocumento> items;
  final String vacio;
  final bool mostrarCantidad;

  /// Marca las líneas que no salieron del inventario.
  final bool mostrarOrigen;

  final void Function(int indice)? onEliminar;

  /// `delta` es +1 o −1. Mueve el stock igual que agregar o quitar la línea.
  final void Function(int indice, int delta)? onCambiarCantidad;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacio.lg),
        child: Text(vacio, style: Tipo.secundario),
      );
    }

    return ListaAgrupada(
      filas: [
        for (var i = 0; i < items.length; i++)
          _Fila(
            linea: items[i],
            mostrarCantidad: mostrarCantidad,
            mostrarOrigen: mostrarOrigen,
            onEliminar: onEliminar == null ? null : () => onEliminar!.call(i),
            onCambiarCantidad: onCambiarCantidad == null
                ? null
                : (delta) => onCambiarCantidad!.call(i, delta),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.linea,
    required this.mostrarCantidad,
    required this.mostrarOrigen,
    this.onEliminar,
    this.onCambiarCantidad,
  });

  final LineaDocumento linea;
  final bool mostrarCantidad;
  final bool mostrarOrigen;
  final VoidCallback? onEliminar;
  final void Function(int delta)? onCambiarCantidad;

  @override
  Widget build(BuildContext context) {
    final externo = linea is LineaRepuesto &&
        (linea as LineaRepuesto).origen == OrigenRepuesto.externo;

    // La segunda línea solo existe si tiene algo que decir. En mano de obra no
    // hay cantidad ni precio unitario que agregar —el importe **es** el
    // precio—, así que repetirlo abajo era decir dos veces lo mismo.
    final rebajada = linea.dtoValido > 0;

    final hayDetalle = onCambiarCantidad != null ||
        mostrarCantidad ||
        rebajada ||
        (mostrarOrigen && externo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        Espacio.md,
        Espacio.xs,
        Espacio.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        linea.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Tipo.encabezado,
                      ),
                    ),
                    const SizedBox(width: Espacio.sm),
                    Text(soles(linea.importe), style: Tipo.monto),
                  ],
                ),
                if (hayDetalle) ...[
                  const SizedBox(height: Espacio.sm),
                  Row(
                    children: [
                      if (onCambiarCantidad != null) ...[
                        _PasoCantidad(
                          icono: Icons.remove_rounded,
                          onTap: () => onCambiarCantidad!(-1),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${linea.cant}',
                            textAlign: TextAlign.center,
                            style: Tipo.monto,
                          ),
                        ),
                        _PasoCantidad(
                          icono: Icons.add_rounded,
                          onTap: () => onCambiarCantidad!(1),
                        ),
                        const SizedBox(width: Espacio.md),
                      ],
                      if (mostrarCantidad)
                        Flexible(
                          child: Text(
                            onCambiarCantidad != null
                                ? '× ${soles(linea.precio)}'
                                : '${linea.cant} × ${soles(linea.precio)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tipo.montoChico,
                          ),
                        ),
                      // La rebaja se ve en la línea, no solo en el total: si
                      // el importe bajó, tiene que decir por qué.
                      if (rebajada) ...[
                        const SizedBox(width: Espacio.sm),
                        Insignia(
                          '−${_sinCola(linea.dtoValido)} %',
                          color: Tono.vinoTexto,
                          fondo: Tono.vinoSuave,
                        ),
                      ],
                      if (mostrarOrigen && externo) ...[
                        const SizedBox(width: Espacio.sm),
                        const Insignia(
                          'Externo',
                          color: Tono.oroTexto,
                          fondo: Tono.oroSuave,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onEliminar != null)
            IconButton(
              onPressed: onEliminar,
              iconSize: 19,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 44),
              color: Tono.texto3,
              tooltip: 'Quitar',
              icon: const Icon(Icons.close_rounded),
            )
          else
            const SizedBox(width: Espacio.sm),
        ],
      ),
    );
  }
}

/// `10.0` → `10`, `7.5` → `7.5`. Un descuento redondo no necesita decimales.
String _sinCola(double n) =>
    n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);

class _PasoCantidad extends StatelessWidget {
  const _PasoCantidad({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.88,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Tono.fondo2,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 18, color: Tono.texto),
        ),
      );
}
