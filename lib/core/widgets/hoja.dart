import 'package:flutter/material.dart';

import '../theme/movimiento.dart';
import '../theme/tipografia.dart';
import '../theme/tokens.dart';

/// Una ventana centrada, del tamaño de lo que tiene adentro.
///
/// Antes esto subía desde abajo como hoja, y **se veía mal**: la hoja tomaba
/// el alto completo de la pantalla y dejaba un vacío blanco enorme arriba de
/// tres opciones. Una ventana que se ajusta a su contenido no puede quedar
/// vacía por construcción.
///
/// Se abre desde el centro, con el resorte de la app y sin rebote. La cruz de
/// arriba a la derecha existe porque una ventana no tiene el tirador de una
/// hoja: sin ella, la única forma de salir sería tocar afuera, y eso no se ve.
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required String titulo,
  String? bajada,
  required Widget Function(BuildContext) contenido,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x8C14130F),
    transitionDuration: Movimiento.normal,
    pageBuilder: (context, _, _) => _Ventana(
      titulo: titulo,
      bajada: bajada,
      child: contenido(context),
    ),
    transitionBuilder: (context, animacion, _, hijo) {
      if (sinAnimaciones(context)) return hijo;

      final curva = CurvedAnimation(
        parent: animacion,
        curve: Movimiento.muelle,
        reverseCurve: Movimiento.salida,
      );

      // Solo opacidad y posición: nada de escalar una ventana con texto
      // adentro, que obliga a rasterizar de nuevo en cada cuadro.
      return FadeTransition(
        opacity: curva,
        child: Transform.translate(
          offset: Offset(0, (1 - curva.value.clamp(0, 1)) * 18),
          child: hijo,
        ),
      );
    },
  );
}

class _Ventana extends StatelessWidget {
  const _Ventana({
    required this.titulo,
    required this.child,
    this.bajada,
  });

  final String titulo;
  final String? bajada;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: Tono.fondo,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Espacio.lg,
        vertical: Espacio.xxl,
      ),
      shape: const RoundedRectangleBorder(borderRadius: Redondeo.brGrande),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Ancho.compacto,
          // Tope, no alto fijo: la ventana mide lo que mide su contenido y
          // solo se frena cuando no entraría en la pantalla.
          maxHeight: alto * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espacio.xl,
                Espacio.xl,
                Espacio.sm,
                Espacio.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: Tipo.titulo1.copyWith(fontSize: 23)),
                        if (bajada != null) ...[
                          const SizedBox(height: Espacio.xs),
                          Text(bajada!, style: Tipo.secundario),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                    iconSize: 20,
                    color: Tono.texto2,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Una opción dentro de una ventana.
///
/// El ícono va **en línea con el título**, no dentro de un cuadradito de color
/// arriba: la fila de "tile + título + descripción" repetida es el patrón que
/// hace que tres opciones distintas se vean como la misma cosa tres veces.
class OpcionHoja extends StatelessWidget {
  const OpcionHoja({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.color = Tono.vino,
    this.destacada = false,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final Color color;

  /// La acción más habitual: se marca con más peso, no con otro color.
  final bool destacada;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacio.xl,
            vertical: Espacio.lg,
          ),
          child: Row(
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(width: Espacio.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: destacada
                          ? Tipo.titulo2
                          : Tipo.titulo2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(detalle, style: Tipo.secundario),
                  ],
                ),
              ),
              const SizedBox(width: Espacio.sm),
              const Icon(Icons.arrow_forward_rounded,
                  color: Tono.texto3, size: 20),
            ],
          ),
        ),
      );
}
