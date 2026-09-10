import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Las estrías de la marca: cortes inclinados, apenas más claros que el fondo.
///
/// Es lo que se lee como velocidad. La inclinación es la misma en toda la app
/// —marcador, cabecera del login, pestaña activa—: dos ángulos distintos en una
/// pantalla se leen como un error de alineación, no como una decisión.
///
/// Van al 6%. Es **textura, no dibujo**: si se ven al mirar, ya compiten con lo
/// que la pantalla tiene que decir.
class EstriasDiagonales extends CustomPainter {
  const EstriasDiagonales({this.cantidad = 3, this.separacion = 46});

  final int cantidad;
  final double separacion;

  @override
  void paint(Canvas lienzo, Size medida) {
    final pincel = Paint()..color = const Color(0x0FFFFFFF);
    final corrimiento = medida.height * 0.42;

    for (var i = 0; i < cantidad; i++) {
      final x = medida.width - 26 - i * separacion;
      final trazo = Path()
        ..moveTo(x, medida.height)
        ..lineTo(x + corrimiento, 0)
        ..lineTo(x + corrimiento + 16, 0)
        ..lineTo(x + 16, medida.height)
        ..close();
      lienzo.drawPath(trazo, pincel);
    }
  }

  @override
  bool shouldRepaint(EstriasDiagonales anterior) =>
      anterior.cantidad != cantidad || anterior.separacion != separacion;
}

/// El logo dentro de un disco claro.
///
/// El logo tiene las letras en gris oscuro y el fondo transparente: puesto
/// directamente sobre el vino se apaga hasta desaparecer. El disco le da la
/// superficie clara que necesita y de paso lo convierte en un emblema, que es
/// como se usa un logo cuando es lo único en el centro de la pantalla.
class Emblema extends StatelessWidget {
  const Emblema({super.key, this.lado = 104});

  final double lado;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        padding: EdgeInsets.all(lado * 0.13),
        decoration: const BoxDecoration(
          color: Tono.textoInverso,
          shape: BoxShape.circle,
          boxShadow: Sombra.alta,
        ),
        child: Image.asset(
          'assets/img/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const FittedBox(
            child: Icon(Icons.bolt_rounded, color: Tono.vino),
          ),
        ),
      );
}
