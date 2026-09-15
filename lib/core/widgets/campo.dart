import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tipografia.dart';
import '../theme/tokens.dart';
import '../utils/validacion.dart';

/// Campo de texto con etiqueta arriba.
///
/// La etiqueta va afuera y no flotando dentro: en un formulario que se llena
/// de a ratos, una etiqueta que desaparece al escribir obliga a acordarse de
/// qué pedía el campo.
///
/// Valida con `AutovalidateMode.onUserInteraction`: **no se pinta de rojo
/// antes de que la persona toque el campo**, pero una vez que lo tocó corrige
/// en vivo, sin esperar a que apriete Guardar para enterarse.
class Campo extends StatefulWidget {
  const Campo({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.ejemplo,
    this.ayuda,
    this.validador,
    this.teclado,
    this.formateadores,
    this.lineas = 1,
    this.autofoco = false,
    this.habilitado = true,
    this.oculto = false,
    this.opcional = false,
    this.prefijo,
    this.prefijoTexto,
    this.sufijo,
    this.onCambio,
    this.onEnviar,
    this.textoAccion,
  });

  final String etiqueta;
  final TextEditingController? controlador;
  final String? ejemplo;

  /// Nota gris debajo. Acompaña, no regaña.
  final String? ayuda;

  /// Ver [Valida] para los validadores ya armados.
  final Validador? validador;

  final TextInputType? teclado;
  final List<TextInputFormatter>? formateadores;
  final int lineas;
  final bool autofoco;
  final bool habilitado;

  /// Contraseñas. Con el teclado del celular a la vista, alguien parado al
  /// lado lee la pantalla entera.
  ///
  /// Trae su propio ojo para mostrarla: tipear a ciegas en un teclado chico
  /// es equivocarse sin saber dónde. Si se pasa un [sufijo], ese reemplaza
  /// al ojo.
  final bool oculto;

  /// Marca el campo como opcional en la etiqueta. Es más honesto que poner un
  /// asterisco en los obligatorios: si casi todo es obligatorio, el asterisco
  /// se vuelve decoración y nadie lo lee.
  final bool opcional;

  final Widget? prefijo;

  /// Un prefijo de texto —"S/"— alineado con la línea base de lo que se
  /// escribe. Va aparte de [prefijo] porque un widget metido como ícono queda
  /// centrado en la caja y no en el renglón, y el símbolo sale flotando por
  /// encima del número.
  final String? prefijoTexto;

  final Widget? sufijo;
  final ValueChanged<String>? onCambio;
  final ValueChanged<String>? onEnviar;
  final TextInputAction? textoAccion;

  @override
  State<Campo> createState() => _CampoState();
}

class _CampoState extends State<Campo> {
  bool _ver = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(w.etiqueta.toUpperCase(), style: Tipo.etiqueta),
            if (w.opcional) ...[
              const SizedBox(width: Espacio.sm),
              Text(
                'OPCIONAL',
                style: Tipo.etiqueta.copyWith(
                  color: Tono.texto3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Espacio.sm),
        TextFormField(
          controller: w.controlador,
          enabled: w.habilitado,
          autofocus: w.autofoco,
          obscureText: w.oculto && !_ver,
          keyboardType: w.lineas > 1 ? TextInputType.multiline : w.teclado,
          inputFormatters: w.formateadores,
          minLines: w.lineas,
          maxLines: w.lineas,
          textInputAction: w.textoAccion,
          onChanged: w.onCambio,
          onFieldSubmitted: w.onEnviar,
          validator: w.validador,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: Tipo.cuerpo,
          decoration: InputDecoration(
            hintText: w.ejemplo,
            helperText: w.ayuda,
            helperStyle: Tipo.nota,
            helperMaxLines: 3,
            errorMaxLines: 3,
            prefixIcon: w.prefijo,
            prefixText: w.prefijoTexto,
            prefixStyle: Tipo.cuerpo.copyWith(color: Tono.texto2),
            suffixIcon: w.sufijo ?? (w.oculto ? _ojo() : null),
            // Blanco cuando se puede escribir, hueso cuando no: el campo
            // bloqueado tiene que verse apagado, no solo no responder.
            fillColor: w.habilitado ? Tono.fondo : Tono.fondo2,
          ),
        ),
      ],
    );
  }

  /// El ojo tachado mientras se ve: el ícono muestra lo que pasa al tocarlo.
  Widget _ojo() => IconButton(
        onPressed: () => setState(() => _ver = !_ver),
        tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
        icon: Icon(
          _ver ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 21,
          color: Tono.texto3,
        ),
      );
}

/// Solo dígitos: pegar `20-13a1` deja `20131`.
final soloDigitosFormato = FilteringTextInputFormatter.digitsOnly;

/// Números con hasta dos decimales, con coma o punto.
final decimalFormato =
    FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'));
