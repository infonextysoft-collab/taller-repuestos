import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/dinero.dart';

/// La barra de abajo de los formularios: el total siempre a la vista y **una**
/// acción principal. Dos botones del mismo peso obligan a leer los dos.
class BarraAccion extends StatelessWidget {
  const BarraAccion({
    super.key,
    required this.texto,
    required this.onTap,
    this.total,
    this.habilitado = true,
    this.secundario,
  });

  final String texto;
  final VoidCallback onTap;

  /// Si va, se muestra a la izquierda. `null` lo oculta.
  final double? total;

  final bool habilitado;

  /// Acción de menor peso, a la izquierda del botón principal.
  final Widget? secundario;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Tono.fondo,
          border: Border(top: BorderSide(color: Tono.linea)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Espacio.md),
            child: Row(
              children: [
                if (total != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL',
                          style: Theme.of(context).textTheme.labelSmall),
                      Text(
                        soles(total),
                        style: const TextStyle(
                          color: Tono.vinoTexto,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: Espacio.lg),
                ],
                if (secundario != null) ...[
                  secundario!,
                  const SizedBox(width: Espacio.md),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: habilitado ? onTap : null,
                    child: Text(texto, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
