import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/dinero.dart';
import '../../core/widgets/campo.dart';
import '../../core/widgets/pulsable.dart';
import '../../domain/entities/linea.dart';

/// Alta de una línea de mano de obra: **qué se hizo y cuánto se cobra**.
///
/// No hay campo de cantidad a propósito. Un trabajo no se vende por unidades:
/// se acuerda un precio y se cobra. El "cantidad 1" que había antes era un
/// campo que nadie tocaba nunca y una pulsación más en cada línea.
class AgregarManoDeObra extends StatefulWidget {
  const AgregarManoDeObra({
    super.key,
    required this.onAgregar,
    this.etiqueta = 'Trabajo realizado',
    this.ejemplo = 'Ej. Rebobinado parcial',
  });

  final ValueChanged<LineaMano> onAgregar;
  final String etiqueta;
  final String ejemplo;

  @override
  State<AgregarManoDeObra> createState() => _AgregarManoDeObraState();
}

class _AgregarManoDeObraState extends State<AgregarManoDeObra> {
  final _desc = TextEditingController();
  final _precio = TextEditingController();
  final _focoDesc = FocusNode();

  bool get _puedeAgregar => _desc.text.trim().isNotEmpty;

  @override
  void dispose() {
    _desc.dispose();
    _precio.dispose();
    _focoDesc.dispose();
    super.dispose();
  }

  void _agregar() {
    if (!_puedeAgregar) return;
    HapticFeedback.selectionClick();

    widget.onAgregar(LineaMano(
      desc: _desc.text.trim(),
      precio: leerNumero(_precio.text),
    ));

    _desc.clear();
    _precio.clear();
    setState(() {});
    // Vuelve al principio: casi siempre viene otra línea detrás.
    _focoDesc.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Campo(
          etiqueta: widget.etiqueta,
          controlador: _desc,
          ejemplo: widget.ejemplo,
          textoAccion: TextInputAction.next,
          onCambio: (_) => setState(() {}),
        ),
        const SizedBox(height: Espacio.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Campo(
                etiqueta: 'Precio',
                controlador: _precio,
                ejemplo: '0.00',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formateadores: [decimalFormato],
                textoAccion: TextInputAction.done,
                onEnviar: (_) => _agregar(),
                prefijoTexto: 'S/ ',
              ),
            ),
            const SizedBox(width: Espacio.md),
            Padding(
              // Queda a la altura de la caja, no de la etiqueta de arriba.
              padding: const EdgeInsets.only(bottom: 1),
              child: Pulsable(
                onTap: _puedeAgregar ? _agregar : null,
                escala: 0.9,
                semantica: 'Agregar trabajo',
                child: AnimatedOpacity(
                  opacity: _puedeAgregar ? 1 : 0.4,
                  duration: const Duration(milliseconds: 130),
                  child: Container(
                    width: kAreaTactil + 6,
                    height: kAreaTactil + 6,
                    decoration: const BoxDecoration(
                      color: Tono.vino,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
