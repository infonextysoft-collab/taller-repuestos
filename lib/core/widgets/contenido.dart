import 'package:flutter/material.dart';

import '../theme/movimiento.dart';
import '../theme/tipografia.dart';
import '../theme/tokens.dart';
import 'pulsable.dart';

/// Centra y limita el ancho del contenido.
///
/// La app corre en celular, tablet y escritorio: sin un tope, en un monitor
/// los formularios quedan de un metro de ancho y el ojo pierde el renglón.
class Contenido extends StatelessWidget {
  const Contenido({
    super.key,
    required this.child,
    this.ancho = Ancho.medio,
    this.padding = const EdgeInsets.symmetric(horizontal: Espacio.lg),
  });

  final Widget child;
  final double ancho;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Un bloque con título.
///
/// El aire de arriba es mayor que el de adentro a propósito: la proximidad es
/// lo que dice qué va con qué, y una sección que respira igual por dentro que
/// por fuera se lee como una lista plana de cosas sueltas.
class Seccion extends StatelessWidget {
  const Seccion({
    super.key,
    this.titulo,
    this.accion,
    required this.child,
  });

  final String? titulo;
  final Widget? accion;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(titulo!.toUpperCase(), style: Tipo.etiqueta),
                ),
                ?accion,
              ],
            ),
            const SizedBox(height: Espacio.md),
          ],
          child,
        ],
      );
}

/// Una superficie blanca. Sin borde y sin sombra: sobre el fondo hueso ya se
/// separa sola, y "borde fino + sombra difusa" en todo hace que nada resalte.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Espacio.lg),
    this.color = Tono.fondo,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: Redondeo.brNormal),
      child: child,
    );

    if (onTap == null) return caja;
    return Pulsable(onTap: onTap, escala: 0.985, child: caja);
  }
}

/// Varias filas dentro de **una sola** superficie, separadas por una línea
/// fina.
///
/// Es lo contrario de darle a cada fila su propia tarjeta con borde y sombra:
/// con veinte tarjetas seguidas la pantalla se vuelve una lista de cajas y
/// cuesta ver dónde termina una y empieza la otra.
class ListaAgrupada extends StatelessWidget {
  const ListaAgrupada({
    super.key,
    required this.filas,
    this.color = Tono.fondo,
  });

  final List<Widget> filas;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: Redondeo.brNormal,
      child: ColoredBox(
        color: color,
        child: Column(
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(left: Espacio.lg),
                  child: Divider(height: 1),
                ),
              filas[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila táctil de una [ListaAgrupada]. En escritorio se ilumina al pasar el
/// mouse: sin cursor táctil no hay otra forma de saber qué es clickeable.
class FilaLista extends StatefulWidget {
  const FilaLista({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Espacio.lg,
      vertical: Espacio.md,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;

  @override
  State<FilaLista> createState() => _FilaListaState();
}

class _FilaListaState extends State<FilaLista> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final fila = AnimatedContainer(
      duration: duracion(context, Movimiento.micro),
      color: _encima && widget.onTap != null ? Tono.fondo2 : Colors.transparent,
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.onTap == null && widget.onLongPress == null) return fila;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: fila,
      ),
    );
  }
}

/// Lo que se ve cuando no hay nada todavía. Dice qué falta y cómo empezar, no
/// "sin datos".
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.titulo,
    this.detalle,
    this.icono = Icons.inbox_rounded,
    this.accion,
  });

  final String titulo;
  final String? detalle;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Espacio.xxxl,
          horizontal: Espacio.lg,
        ),
        child: Column(
          children: [
            Icon(icono, size: 40, color: Tono.lineaFuerte),
            const SizedBox(height: Espacio.lg),
            Text(titulo, textAlign: TextAlign.center, style: Tipo.titulo2),
            if (detalle != null) ...[
              const SizedBox(height: Espacio.sm),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: Tipo.secundario,
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: Espacio.xl),
              accion!,
            ],
          ],
        ),
      );
}

/// Etiqueta de estado: pendiente, vencido, agotado, externo.
class Insignia extends StatelessWidget {
  const Insignia(
    this.texto, {
    super.key,
    this.color = Tono.texto2,
    this.fondo = Tono.fondo2,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
          left: icono == null ? Espacio.sm + 2 : Espacio.sm,
          right: Espacio.sm + 2,
          top: 3,
          bottom: 3,
        ),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
}
