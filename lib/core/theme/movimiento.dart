import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Duraciones y curvas de toda la app.
///
/// Todo se mueve con un **resorte críticamente amortiguado**: llega rápido y
/// se asienta, sin pasarse. El rebote quedó afuera a propósito — en una
/// interfaz de trabajo se siente anticuado, y el usuario no lanzó nada: tocó
/// un botón. El rebote solo tiene sentido cuando el gesto **traía momentum**
/// de verdad (un flick), y acá no hay ninguno.
class Movimiento {
  const Movimiento._();

  /// Micro-interacciones: presión de un botón, aparición de un tilde.
  static const Duration micro = Duration(milliseconds: 130);

  /// Lo normal: cambiar de pestaña, abrir un panel.
  static const Duration normal = Duration(milliseconds: 260);

  /// Entradas de pantalla.
  static const Duration entrada = Duration(milliseconds: 420);

  /// Tope duro del contenido de la apertura. Con los 600 ms que tarda el
  /// portón en subir, el arranque completo queda en 3 s contra el reloj, que
  /// es lo máximo que alguien espera por ver una marca.
  static const Duration apertura = Duration(milliseconds: 2400);

  /// Salida rápida, sin ceremonia.
  static const Curve salida = Curves.easeOutCubic;

  /// Resorte crítico: llega y se queda. Sin overshoot.
  static final Curve muelle = CurvaMuelle();

  /// El mismo resorte, más suelto: para superficies grandes que suben —una
  /// hoja pesa más que un botón, y llegar de golpe se ve barato—.
  static final Curve muelleAmplio =
      CurvaMuelle(rigidez: 210, amortiguacion: 29, segundos: 0.6);
}

/// Una [Curve] construida sobre la física real de un resorte.
///
/// Con `amortiguacion = 2·√(masa·rigidez)` el resorte queda **críticamente
/// amortiguado**: la curva llega al destino lo más rápido posible sin pasarse.
class CurvaMuelle extends Curve {
  CurvaMuelle({
    double masa = 1,
    double rigidez = 380,
    double amortiguacion = 39,
    this.segundos = 0.42,
  }) : _sim = SpringSimulation(
          SpringDescription(
            mass: masa,
            stiffness: rigidez,
            damping: amortiguacion,
          ),
          0,
          1,
          0,
        );

  final SpringSimulation _sim;

  /// Cuánto tiempo real representa el tramo 0→1 de la curva.
  final double segundos;

  @override
  double transformInternal(double t) => _sim.x(t * segundos);
}

/// ¿El sistema pidió menos animación? Se respeta siempre.
bool sinAnimaciones(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Duración efectiva: cero si el sistema pidió no animar.
Duration duracion(BuildContext context, Duration d) =>
    sinAnimaciones(context) ? Duration.zero : d;

/// Transición **direccional** entre pasos del wizard: avanzar entra desde la
/// derecha, retroceder desde la izquierda. Sin eso, ir y volver se ve igual y
/// nadie sabe hacia dónde se movió.
class TransicionDireccional extends StatelessWidget {
  const TransicionDireccional({
    super.key,
    required this.indice,
    required this.haciaAdelante,
    required this.child,
  });

  /// Cambiar este valor dispara la transición.
  final int indice;
  final bool haciaAdelante;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duracion(context, Movimiento.normal),
      switchInCurve: Movimiento.muelle,
      switchOutCurve: Movimiento.salida,
      layoutBuilder: (actual, anteriores) => Stack(
        alignment: Alignment.topCenter,
        children: [...anteriores, ?actual],
      ),
      transitionBuilder: (hijo, animacion) {
        final entra = hijo.key == ValueKey(indice);
        final signo = haciaAdelante ? 1.0 : -1.0;
        final desde = entra ? signo * 0.06 : -signo * 0.06;

        return FadeTransition(
          opacity: animacion,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(desde, 0),
              end: Offset.zero,
            ).animate(animacion),
            child: hijo,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(indice), child: child),
    );
  }
}

/// Entrada suave de un bloque: sube un poco y aparece.
///
/// No se usa escalonada en listas — el historial se abre veinte veces por día
/// y esa animación se vuelve fricción a la semana.
class EntradaSuave extends StatefulWidget {
  const EntradaSuave({
    super.key,
    required this.child,
    this.retraso = Duration.zero,
    this.desplazamiento = 12,
  });

  final Widget child;
  final Duration retraso;
  final double desplazamiento;

  @override
  State<EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<EntradaSuave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Movimiento.entrada,
  );

  @override
  void initState() {
    super.initState();
    if (widget.retraso == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.retraso, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sinAnimaciones(context)) return widget.child;

    final curva = CurvedAnimation(parent: _c, curve: Movimiento.muelle);

    return AnimatedBuilder(
      animation: curva,
      builder: (context, hijo) => Opacity(
        opacity: curva.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - curva.value) * widget.desplazamiento),
          child: hijo,
        ),
      ),
      child: widget.child,
    );
  }
}
