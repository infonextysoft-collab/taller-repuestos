import 'package:flutter/material.dart';

import '../theme/tipografia.dart';
import '../theme/tokens.dart';
import '../utils/imagenes.dart';

/// La cara de un registro en una lista.
///
/// Muestra la foto de ingreso del equipo. Cuando todavía no hay ninguna, cae a
/// la inicial del cliente en vez de a un ícono genérico: un ícono repetido
/// cincuenta veces hacia abajo es ruido con forma de patrón, mientras que las
/// iniciales cambian fila a fila y ayudan a encontrar lo que se busca.
class Miniatura extends StatelessWidget {
  const Miniatura({
    super.key,
    required this.foto,
    required this.nombre,
    this.lado = 50,
  });

  final String? foto;
  final String nombre;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDeFoto(foto);

    return ClipRRect(
      borderRadius: Redondeo.brChico,
      child: SizedBox(
        width: lado,
        height: lado,
        child: bytes == null
            ? _Inicial(nombre: nombre, lado: lado)
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _Inicial(nombre: nombre, lado: lado),
              ),
      ),
    );
  }
}

class _Inicial extends StatelessWidget {
  const _Inicial({required this.nombre, required this.lado});

  final String nombre;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final limpio = nombre.trim();
    final letra = limpio.isEmpty ? '?' : limpio[0].toUpperCase();

    return ColoredBox(
      color: Tono.fondo2,
      child: Center(
        child: Text(
          letra,
          style: Tipo.titulo2.copyWith(
            fontSize: lado * 0.42,
            color: Tono.texto3,
          ),
        ),
      ),
    );
  }
}
