import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pulsable.dart';

/// Cuánto alto reserva la barra por encima del área segura.
///
/// Las pantallas lo suman a su padding de abajo: la barra **flota** sobre el
/// contenido, así que si no se reserva, la última fila de cualquier lista queda
/// debajo del vidrio y no hay forma de tocarla.
const double kAltoBarra = 90;

/// `Historial · Inventario · [+] · Avisos`
///
/// Es una pastilla oscura que flota sobre el contenido, no una barra pegada al
/// borde. Dos razones, ninguna estética: el contenido pasa por debajo y se ve
/// que la lista sigue, y la superficie oscura le da peso al pie sin sumar un
/// tercer color de marca.
///
/// El desenfoque va **solo acá**. Es lo único de la app que tiene contenido
/// moviéndose por detrás, y un `backdrop-filter` por cada tarjeta de una lista
/// que scrollea es de lo más caro que se le puede pedir a un teléfono de gama
/// media.
class BarraInferior extends StatelessWidget {
  const BarraInferior({
    super.key,
    required this.seccion,
    required this.onSeccion,
    required this.onNuevo,
    this.vencidos = 0,
  });

  /// 0 historial · 1 inventario · 2 recordatorios
  final int seccion;
  final ValueChanged<int> onSeccion;
  final VoidCallback onNuevo;

  /// Pinta la marca sobre Avisos.
  final int vencidos;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Espacio.lg,
        0,
        Espacio.lg,
        abajo > 0 ? abajo : Espacio.md,
      ),
      child: SizedBox(
        height: kAltoBarra,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // La sombra va **afuera** del recorte. Adentro quedaba cortada por
            // el propio ClipRRect y en vez de sombra se veía un borde sucio
            // alrededor de la pastilla.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 62,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Tono.negro,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  // Más cerrada que `Sombra.alta`: una sombra muy abierta bajo
                  // una pastilla oscura se lee como una mancha gris pegada
                  // abajo, no como que la barra flota.
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x2814130F),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 62,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(
                    color: const Color(0xF012110F),
                    // Cuatro ranuras iguales: tres pestañas y el hueco del
                    // botón. Todas `Expanded`, sin anchos fijos, para que se
                    // repartan parejo en cualquier pantalla.
                    child: Row(
                      children: [
                        _Tab(
                          icono: Icons.receipt_long_rounded,
                          etiqueta: 'Historial',
                          activo: seccion == 0,
                          onTap: () => onSeccion(0),
                        ),
                        _Tab(
                          icono: Icons.inventory_2_rounded,
                          etiqueta: 'Inventario',
                          activo: seccion == 1,
                          onTap: () => onSeccion(1),
                        ),
                        const Spacer(),
                        _Tab(
                          icono: Icons.notifications_rounded,
                          etiqueta: 'Avisos',
                          activo: seccion == 2,
                          marca: vencidos,
                          onTap: () => onSeccion(2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // El "+" va centrado en la **tercera de cuatro ranuras**, la misma
            // que queda vacía en la fila de abajo. Así los cuatro lugares miden
            // igual: antes el hueco era un ancho fijo y desbalanceaba la fila,
            // que dejaba a Historial e Inventario apretados a la izquierda y a
            // Avisos suelto contra el borde.
            Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: Row(
                children: [
                  const Spacer(flex: 2),
                  Expanded(child: Center(child: _BotonNuevo(onTap: onNuevo))),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.marca = 0,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final int marca;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Sobre negro, el oro es lo que se ve: el vino se apaga contra él.
    final color = activo ? Tono.oroVivo : Tono.textoInverso2;

    return Expanded(
      child: Pulsable(
        onTap: onTap,
        escala: 0.92,
        semantica: etiqueta,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icono, size: 21, color: color),
                  if (marca > 0)
                    Positioned(
                      right: -7,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Tono.vino,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Tono.negro, width: 1.5),
                        ),
                        child: Text(
                          marca > 9 ? '9+' : '$marca',
                          style: Tipo.nota.copyWith(
                            color: Tono.textoInverso,
                            fontSize: 9.5,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                etiqueta,
                style: Tipo.nota.copyWith(fontSize: 10.5, color: color),
              ),
              const SizedBox(height: 4),
              // Un trazo inclinado, no un punto: es la misma diagonal que usa
              // el marcador, y así la pestaña activa se marca con la forma de
              // la marca en vez de con otro color más.
              Transform(
                transform: Matrix4.skewX(-0.32),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: duracion(context, Movimiento.micro),
                  curve: Movimiento.salida,
                  height: 3,
                  width: activo ? 16 : 0,
                  color: Tono.oroVivo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El "+": sobresale de la pastilla y es lo único lleno de vino del pie.
///
/// Sube por encima del borde a propósito. Es una acción, no una pestaña, y
/// tiene que leerse distinto sin necesidad de una etiqueta.
class _BotonNuevo extends StatelessWidget {
  const _BotonNuevo({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.9,
        semantica: 'Nuevo registro',
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Tono.vino, Tono.vinoHondo],
            ),
            shape: BoxShape.circle,
            // El anillo de oro es lo que lo despega del negro de la pastilla:
            // sin él, el círculo se funde con la barra en pantallas chicas.
            border: Border.fromBorderSide(
              BorderSide(color: Tono.oroClaro, width: 1.5),
            ),
            boxShadow: Sombra.alta,
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Tono.textoInverso,
            size: 28,
          ),
        ),
      );
}
