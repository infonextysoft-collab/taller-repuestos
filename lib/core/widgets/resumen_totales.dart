import 'package:flutter/material.dart';

import '../../domain/entities/totales.dart';
import '../theme/tipografia.dart';
import '../theme/tokens.dart';
import '../utils/dinero.dart';

/// El bloque de totales, igual en pantalla que en el papel.
///
/// El total es lo más grande de la pantalla: es el único número que la persona
/// va a leer en voz alta. El desagregado del IGV va **debajo** y en chico,
/// porque el impuesto ya está adentro y no se le suma — ponerlo antes del
/// total, como en una factura común, contaría la historia al revés.
class ResumenTotales extends StatelessWidget {
  const ResumenTotales({
    super.key,
    required this.totales,
    this.titulo,
  });

  final Totales totales;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final t = totales;

    return Container(
      padding: const EdgeInsets.all(Espacio.xl),
      decoration: BoxDecoration(
        color: Tono.fondo,
        borderRadius: Redondeo.brNormal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Text(titulo!.toUpperCase(), style: Tipo.etiqueta),
            const SizedBox(height: Espacio.lg),
          ],
          if (t.subTrabajos > 0)
            _Fila(etiqueta: 'Mano de obra', valor: t.subTrabajos),
          if (t.subRepuestos > 0)
            _Fila(etiqueta: 'Repuestos', valor: t.subRepuestos),
          if (t.subTraslado > 0)
            _Fila(etiqueta: 'Traslado', valor: t.subTraslado),
          if (t.descuento > 0) ...[
            _Fila(etiqueta: 'Subtotal', valor: t.subtotal),
            _Fila(
              etiqueta: 'Descuento',
              valor: -t.descuento,
              destacado: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Espacio.lg),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'TOTAL',
                  style: Tipo.etiqueta.copyWith(color: Tono.texto2),
                ),
              ),
              Text(soles(t.total), style: Tipo.montoGrande),
            ],
          ),
          const SizedBox(height: Espacio.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacio.md,
              vertical: Espacio.sm,
            ),
            decoration: BoxDecoration(
              color: Tono.oroSuave,
              borderRadius: Redondeo.brChico,
            ),
            child: Column(
              children: [
                _Nota(etiqueta: 'Op. gravada', valor: t.gravado),
                const SizedBox(height: 2),
                _Nota(etiqueta: 'IGV (18%) incluido', valor: t.igv),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  final String etiqueta;
  final double valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(etiqueta, style: Tipo.secundario)),
            Text(
              soles(valor),
              style: Tipo.montoChico.copyWith(
                color: destacado ? Tono.vino : Tono.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _Nota extends StatelessWidget {
  const _Nota({required this.etiqueta, required this.valor});

  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: Tipo.nota.copyWith(color: Tono.oroTexto),
            ),
          ),
          Text(
            soles(valor),
            style: Tipo.nota.copyWith(
              color: Tono.oroTexto,
              fontWeight: FontWeight.w700,
              fontFeatures: kNumerosTabulares,
            ),
          ),
        ],
      );
}
