import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';

/// La bienvenida: un portón de taller que se levanta.
///
/// La idea está tomada de cómo abre Netflix, pero de lo que de verdad la hace
/// funcionar, que no es el brillo: **la animación termina metiéndote en el
/// producto**. Acá la portada no se descarta con un fundido; es un portón, se
/// levanta, y detrás ya está la app montada. La entrada *es* la transición.
///
/// Mientras el portón está abajo, el nombre del negocio se marca con una
/// **soldadura**: un punto de luz recorre el trazo, deja la letra al blanco y
/// enfría a dorado. Tres o cuatro chispas, no una fiesta.
///
/// Y corre el arranque real por detrás: refrescar vencidos y ver si hay sesión.
/// Dos topes: un **mínimo** para que no parpadee, y un **máximo** de 2.4 s más
/// los 0.6 s del portón — tres segundos contra el reloj, pase lo que pase.
class PantallaApertura extends ConsumerStatefulWidget {
  const PantallaApertura({super.key, required this.alTerminar});

  /// Se llama con `true` si ya había sesión abierta.
  final void Function(bool haySesion) alTerminar;

  /// Lo suficiente para que se lea como una entrada y no como un parpadeo.
  static const Duration minimo = Duration(milliseconds: 1700);

  /// Tope duro del contenido. Con el portón encima, el total no pasa de 3 s.
  static const Duration maximo = Movimiento.apertura;

  /// Lo que tarda el portón en subir.
  static const Duration porton = Duration(milliseconds: 600);

  @override
  ConsumerState<PantallaApertura> createState() => _PantallaAperturaState();
}

class _PantallaAperturaState extends ConsumerState<PantallaApertura>
    with TickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );

  late final AnimationController _salida = AnimationController(
    vsync: this,
    duration: PantallaApertura.porton,
  );

  bool _yaSalio = false;

  /* ------------------------------------------------------------- tiempos */

  /// La soldadura recorre el nombre. Va con una curva propia y no con el
  /// resorte de la app: un arco de soldadura avanza parejo, no se asienta.
  late final Animation<double> _soldadura = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0.06, 0.60, curve: Curves.easeInOutSine),
  );

  late final Animation<double> _regla = _tramo(0.56, 0.80);
  late final Animation<double> _bajada = _tramo(0.68, 0.96);

  Animation<double> _tramo(double desde, double hasta) => CurvedAnimation(
        parent: _entrada,
        curve: Interval(desde, hasta, curve: Movimiento.muelle),
      );

  @override
  void initState() {
    super.initState();
    _entrada.forward();
    _arrancar();

    // Seguro de vida: si el arranque se colgara, al tope se entra igual.
    Future.delayed(PantallaApertura.maximo, () {
      if (mounted && !_yaSalio) _terminar(false);
    });
  }

  Future<void> _arrancar() async {
    final reloj = Stopwatch()..start();

    var haySesion = false;
    try {
      await ref.read(recordatoriosRepoProvider).refrescarVencidos();
      haySesion = await ref.read(authRepoProvider).haySesion();
      ref.invalidate(vencidosProvider);
    } catch (_) {
      // Un arranque a medias no puede dejar la app encerrada en la portada:
      // se entra igual y la pantalla que corresponda mostrará el problema.
    }

    final falta = PantallaApertura.minimo - reloj.elapsed;
    if (falta > Duration.zero) await Future.delayed(falta);

    await _terminar(haySesion);
  }

  Future<void> _terminar(bool haySesion) async {
    if (_yaSalio || !mounted) return;
    _yaSalio = true;

    if (!sinAnimaciones(context)) await _salida.forward();
    if (mounted) widget.alTerminar(haySesion);
  }

  @override
  void dispose() {
    _entrada.dispose();
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioProvider).nombre.trim();
    final nombre = negocio.isEmpty ? 'MS' : negocio.toUpperCase();
    final quieto = sinAnimaciones(context);

    return Scaffold(
      backgroundColor: Tono.negro,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrada, _salida]),
        builder: (context, _) {
          // El portón arranca lento —el motor engancha— y después sube parejo.
          final subida = Curves.easeInCubic.transform(_salida.value);
          final alto = MediaQuery.sizeOf(context).height;

          return Transform.translate(
            // Solo posición: nada de opacidad ni blur sobre una pantalla
            // entera, que obliga a recomponer todo en cada frame.
            offset: Offset(0, -alto * subida),
            child: _Porton(
              luz: _salida.value,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Soldadura(
                        texto: nombre,
                        avance: quieto ? 1 : _soldadura.value,
                      ),
                      const SizedBox(height: Espacio.lg),
                      _ReglaOro(avance: quieto ? 1 : _regla.value),
                      const SizedBox(height: Espacio.xl),
                      Opacity(
                        opacity: quieto ? 1 : _bajada.value.clamp(0, 1),
                        child: Text(
                          'TRABAJOS · REPUESTOS · DOCUMENTOS',
                          textAlign: TextAlign.center,
                          style: Tipo.etiqueta.copyWith(
                            color: Tono.textoInverso2,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// La chapa del portón: bandas horizontales sobre negro.
///
/// Las bandas están al 3% y 5%. Es lo que hace que el fondo se lea como una
/// **cosa** que se levanta y no como un color plano deslizándose; si se ven al
/// mirar, ya son demasiado.
class _Porton extends StatelessWidget {
  const _Porton({required this.child, required this.luz});

  /// Cuánto abrió el portón, 0..1. Enciende la luz del borde de abajo.
  final double luz;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Tono.negro2, Tono.negro],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _Bandas())),
            Positioned.fill(child: child),
            // La luz que se escapa por debajo. Está desde el principio, apenas
            // insinuada, y crece cuando el portón empieza a subir: es lo que
            // dice que del otro lado hay algo encendido esperando.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3 + luz * 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Tono.oroVivo,
                  boxShadow: [
                    BoxShadow(
                      color: Tono.oroVivo.withValues(alpha: 0.35 + luz * 0.45),
                      blurRadius: 18 + luz * 26,
                      spreadRadius: luz * 5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Bandas extends CustomPainter {
  const _Bandas();

  static const double _alto = 38;

  @override
  void paint(Canvas lienzo, Size medida) {
    final brillo = Paint()..color = const Color(0x0DFFFFFF);
    final junta = Paint()..color = const Color(0x33000000);

    for (var y = 0.0; y < medida.height; y += _alto) {
      lienzo.drawRect(Rect.fromLTWH(0, y, medida.width, 1.5), brillo);
      lienzo.drawRect(
        Rect.fromLTWH(0, y + _alto - 1.5, medida.width, 1.5),
        junta,
      );
    }
  }

  @override
  bool shouldRepaint(_Bandas anterior) => false;
}

/// El nombre soldándose.
///
/// El degradado del [ShaderMask] viaja con el avance: detrás del arco la letra
/// queda dorada —ya enfrió—, en el arco está al blanco, y adelante todavía no
/// existe. Es un solo `Text`, así que sale gratis en cualquier nombre.
class _Soldadura extends StatelessWidget {
  const _Soldadura({required this.texto, required this.avance});

  final String texto;
  final double avance;

  @override
  Widget build(BuildContext context) {
    final t = avance.clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (caja) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Tono.oroClaro,
              Tono.oroVivo,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ],
            stops: [
              0,
              math.max(0, t - 0.16),
              math.max(0.001, t - 0.01),
              math.min(1, t + 0.005),
              1,
            ],
          ).createShader(caja),
          child: FittedBox(
            child: Text(
              texto,
              maxLines: 1,
              style: Tipo.display.copyWith(
                fontSize: 64,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (t > 0.02 && t < 0.995)
          Positioned.fill(child: CustomPaint(painter: _Chispas(t))),
      ],
    );
  }
}

/// El arco y las chispas, en la punta de la soldadura.
///
/// Las chispas salen de una secuencia fija sembrada con el índice, no de un
/// azar nuevo por frame: si cambiaran en cada cuadro se verían como ruido de
/// televisión en vez de partículas.
class _Chispas extends CustomPainter {
  const _Chispas(this.avance);

  final double avance;

  @override
  void paint(Canvas lienzo, Size medida) {
    final x = medida.width * avance;
    final y = medida.height * 0.55;

    lienzo.drawCircle(
      Offset(x, y),
      5,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    lienzo.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);

    final azar = math.Random(7);
    for (var i = 0; i < 5; i++) {
      // Cada chispa tiene su propio ciclo, así no salen todas juntas.
      final fase = (avance * 6 + i * 0.37) % 1;
      final angulo = -math.pi / 2 + (azar.nextDouble() - 0.5) * 2.4;
      final largo = (14 + azar.nextDouble() * 22) * fase;

      final desde = Offset(x, y);
      final hasta = Offset(
        x + math.cos(angulo) * largo,
        y + math.sin(angulo) * largo + fase * fase * 16,
      );

      lienzo.drawLine(
        desde,
        hasta,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(Colors.white, Tono.oroVivo, fase)!
              .withValues(alpha: 1 - fase),
      );
    }
  }

  @override
  bool shouldRepaint(_Chispas anterior) => anterior.avance != avance;
}

/// La regla de oro debajo del nombre: se traza de adentro hacia afuera.
class _ReglaOro extends StatelessWidget {
  const _ReglaOro({required this.avance});

  final double avance;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 3,
        width: 220,
        child: FractionallySizedBox(
          widthFactor: avance.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Tono.oro, Tono.oroVivo, Tono.oro],
              ),
            ),
          ),
        ),
      );
}
