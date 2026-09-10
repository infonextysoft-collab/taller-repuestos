import 'package:flutter/material.dart';

import '../theme/movimiento.dart';
import '../theme/tokens.dart';
import '../utils/documento.dart';
import '../utils/validacion.dart';
import 'campo.dart';

/// Campo de DNI / RUC.
///
/// El campo **no se pinta de rojo mientras la persona teclea**: escribir `204`
/// no es un error, es un RUC a medio escribir, y regañar a alguien por el
/// tercer dígito lo entrena a ignorar todos los avisos. Mientras escribe ve la
/// ayuda gris ("RUC — faltan 6 dígitos"); el rojo aparece recién cuando el
/// número está completo y no cuadra, o al intentar guardar.
class CampoDocumento extends StatefulWidget {
  const CampoDocumento({
    super.key,
    required this.controlador,
    this.etiqueta = 'RUC / DNI',
    this.soloRuc = false,
    this.habilitado = true,
    this.obligatorio = false,
    this.onCambio,
  });

  final TextEditingController controlador;
  final String etiqueta;

  /// En Datos del negocio se exige RUC sí o sí: es el emisor del documento,
  /// no puede ser un DNI.
  final bool soloRuc;

  final bool habilitado;
  final bool obligatorio;
  final ValueChanged<String>? onCambio;

  @override
  State<CampoDocumento> createState() => _CampoDocumentoState();
}

class _CampoDocumentoState extends State<CampoDocumento> {
  @override
  Widget build(BuildContext context) {
    final revision =
        revisarDocumento(widget.controlador.text, soloRuc: widget.soloRuc);
    final valido = revision.estado == EstadoDocumento.valido;

    return Campo(
      etiqueta: widget.etiqueta,
      controlador: widget.controlador,
      habilitado: widget.habilitado,
      opcional: !widget.obligatorio,
      ejemplo: widget.soloRuc ? '20131312955' : '12345678',
      teclado: TextInputType.number,
      formateadores: [soloDigitosFormato],
      // La ayuda acompaña mientras se escribe; el validador solo grita cuando
      // el número está completo y mal, o cuando falta y hace falta.
      ayuda: revision.mensaje,
      validador: Valida.todos([
        if (widget.obligatorio) Valida.obligatorio('el RUC'),
        Valida.documento(soloRuc: widget.soloRuc),
      ]),
      onCambio: (valor) {
        setState(() {});
        widget.onCambio?.call(valor);
      },
      sufijo: AnimatedSwitcher(
        duration: duracion(context, Movimiento.micro),
        child: valido
            ? const Icon(
                Icons.check_circle_rounded,
                key: ValueKey('ok'),
                color: Tono.oro,
                size: 21,
              )
            : const SizedBox.shrink(key: ValueKey('nada')),
      ),
    );
  }
}
