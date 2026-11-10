import 'package:flutter/material.dart';

import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/recordatorio.dart';

/// Lo que se muestra como título. Un aviso sin texto igual tiene que decir algo.
String tituloDe(Recordatorio r) =>
    r.descripcion.trim().isEmpty ? 'Sin descripción' : r.descripcion.trim();

/// "Cliente · Equipo", o `null` si no tiene ninguno de los dos.
String? clienteEquipoDe(Recordatorio r) {
  final partes = [
    if ((r.cliente ?? '').trim().isNotEmpty) r.cliente!.trim(),
    if ((r.equipo ?? '').trim().isNotEmpty) r.equipo!.trim(),
  ];
  return partes.isEmpty ? null : partes.join(' · ');
}

/// La píldora de la fecha. Tres colores y nada más: rojo lo que venció, oro
/// lo de hoy, gris lo que falta.
class ChipFecha extends StatelessWidget {
  const ChipFecha({super.key, required this.fecha});

  final String fecha;

  @override
  Widget build(BuildContext context) {
    final d = diasHasta(fecha);
    final (color, fondo) = d < 0
        ? (Tono.vinoTexto, Tono.vinoSuave)
        : d == 0
        ? (Tono.oroTexto, Tono.oroSuave)
        : (Tono.texto2, Tono.fondo2);

    return _Pildora(texto: fechaEnPalabras(fecha), color: color, fondo: fondo);
  }
}

/// La píldora de cada cuánto se repite.
class ChipRepite extends StatelessWidget {
  const ChipRepite({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => _Pildora(
    texto: texto,
    color: Tono.texto2,
    fondo: Tono.fondo2,
    icono: Icons.autorenew_rounded,
  );
}

class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.texto,
    required this.color,
    required this.fondo,
    this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: color),
          const SizedBox(width: Espacio.xs),
        ],
        Flexible(
          child: Text(
            texto,
            style: Tipo.nota.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// El botón redondo de cumplido. Siempre a la vista, también en los vencidos:
/// que se haya pasado la fecha no quita que se pueda haber hecho.
class BotonCumplir extends StatelessWidget {
  const BotonCumplir({super.key, required this.onTap, this.tamano = 52});

  final VoidCallback onTap;
  final double tamano;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Marcar cumplido',
    child: Material(
      color: Tono.fondo2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Icon(Icons.check_rounded, size: tamano / 2, color: Tono.texto),
        ),
      ),
    ),
  );
}

/// Un aviso. Toda la tarjeta abre el detalle; el círculo lo marca cumplido.
class TarjetaAviso extends StatelessWidget {
  const TarjetaAviso({
    super.key,
    required this.recordatorio,
    required this.onTap,
    required this.onCumplir,
  });

  final Recordatorio recordatorio;
  final VoidCallback onTap;
  final VoidCallback onCumplir;

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;
    final detalle = clienteEquipoDe(r);

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        Espacio.lg,
        Espacio.md,
        Espacio.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        tituloDe(r),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Tipo.encabezado.copyWith(fontSize: 17),
                      ),
                    ),
                    if (r.importante) ...[
                      const SizedBox(width: Espacio.xs),
                      const Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: Tono.oro,
                        semanticLabel: 'Importante',
                      ),
                    ],
                  ],
                ),
                if (detalle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.secundario,
                  ),
                ],
                const SizedBox(height: Espacio.md),
                Wrap(
                  spacing: Espacio.sm,
                  runSpacing: Espacio.xs,
                  children: [
                    ChipFecha(fecha: r.fecha),
                    if (r.seRepite) ChipRepite(texto: r.repite!.etiqueta),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Espacio.md),
          BotonCumplir(onTap: onCumplir),
        ],
      ),
    );
  }
}
