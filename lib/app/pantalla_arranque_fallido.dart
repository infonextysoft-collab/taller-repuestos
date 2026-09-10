import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// Lo que se ve si la app no logra arrancar.
///
/// Existe porque una pantalla en blanco es el peor final posible: no dice qué
/// pasó, no dice qué hacer, y obliga a abrir la consola del navegador para
/// enterarse. Prefiero un cartel feo con el error de verdad.
class PantallaArranqueFallido extends StatelessWidget {
  const PantallaArranqueFallido({
    super.key,
    required this.error,
    required this.traza,
  });

  final Object error;
  final StackTrace traza;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Tono.fondo,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Espacio.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Ancho.lectura),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Tono.vino, size: 34),
                    const SizedBox(height: Espacio.md),
                    const Text(
                      'La app no pudo arrancar',
                      style: TextStyle(
                        color: Tono.texto,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: Espacio.sm),
                    const Text(
                      'Falló la apertura de la base de datos local. Tus datos '
                      'no se perdieron: siguen en el dispositivo.',
                      style: TextStyle(color: Tono.texto2, fontSize: 14),
                    ),
                    const SizedBox(height: Espacio.xl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Espacio.md),
                      decoration: BoxDecoration(
                        color: Tono.fondo2,
                        borderRadius: Redondeo.brChico,
                        border: Border.all(color: Tono.linea),
                      ),
                      child: SelectableText(
                        '$error\n\n$traza',
                        style: const TextStyle(
                          color: Tono.texto2,
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
