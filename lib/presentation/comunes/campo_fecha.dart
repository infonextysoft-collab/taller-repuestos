import 'package:flutter/material.dart';

import '../../core/theme/tipografia.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/fechas.dart';

/// La fecha del registro.
///
/// Se puede mover porque a veces se carga al día siguiente, pero arranca en
/// hoy: escribir la fecha a mano en cada registro sería el campo más tocado y
/// más equivocado de la app.
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.fecha,
    required this.onCambio,
    this.etiqueta = 'Fecha',
    this.habilitado = true,
  });

  final String fecha;
  final ValueChanged<String> onCambio;
  final String etiqueta;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final valor = fecha.isEmpty ? hoyISO() : fecha;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta.toUpperCase(), style: Tipo.etiqueta),
        const SizedBox(height: Espacio.sm),
        InkWell(
          borderRadius: Redondeo.brChico,
          onTap: habilitado
              ? () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: fechaDe(valor),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(DateTime.now().year + 2),
                  );
                  if (elegida != null) onCambio(isoDe(elegida));
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacio.lg,
              vertical: Espacio.lg,
            ),
            decoration: BoxDecoration(
              color: habilitado ? Tono.fondo2 : Tono.linea,
              borderRadius: Redondeo.brChico,
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 20, color: Tono.texto2),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: Text(formatoLargo(valor), style: Tipo.cuerpo),
                ),
                if (habilitado)
                  Text(
                    'Cambiar',
                    style: Tipo.secundario.copyWith(
                      color: Tono.vinoTexto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
