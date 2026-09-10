import 'package:flutter/material.dart';

import '../theme/movimiento.dart';

/// Envuelve cualquier cosa y le da respuesta al tacto.
///
/// El hundido ocurre en **pointer-down**, no al soltar: si la confirmación
/// llega recién al levantar el dedo, la interfaz se siente lenta aunque el
/// tiempo total sea el mismo. Se anima solo la escala — nunca opacidad sobre
/// algo con blur detrás.
class Pulsable extends StatefulWidget {
  const Pulsable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.escala = 0.97,
    this.semantica,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double escala;
  final String? semantica;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _hundido = false;

  void _marcar(bool valor) {
    if (widget.onTap == null || _hundido == valor) return;
    setState(() => _hundido = valor);
  }

  @override
  Widget build(BuildContext context) {
    final contenido = AnimatedScale(
      scale: _hundido ? widget.escala : 1,
      duration: duracion(context, Movimiento.micro),
      curve: Movimiento.salida,
      child: widget.child,
    );

    return Semantics(
      button: widget.onTap != null,
      label: widget.semantica,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _marcar(true),
        onTapUp: (_) => _marcar(false),
        onTapCancel: () => _marcar(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: contenido,
      ),
    );
  }
}
