import 'package:flutter/material.dart';

import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/campo.dart';

/// Los bancos y cajas con los que se cobra en Perú.
///
/// La lista es **para no tipear**, no un catálogo cerrado: al final está
/// "Otro", y ahí se escribe el que sea. Por eso no hace falta que estén todos
/// ni mantenerla al día: lo que falte se carga a mano una vez y queda.
const bancosDelPeru = <String>[
  'BCP',
  'BBVA',
  'Interbank',
  'Scotiabank',
  'Banco de la Nación',
  'BanBif',
  'Banco Pichincha',
  'Mibanco',
  'Caja Arequipa',
  'Caja Huancayo',
  'Caja Piura',
  'Caja Trujillo',
  'Caja Sullana',
  'Caja Cusco',
];

/// El valor del ítem "Otro": no es el nombre de ningún banco, así que no se
/// puede confundir con uno cargado a mano.
const _otro = '\u0000otro';

/// Elegir el banco de una lista, o escribirlo si no está.
///
/// Antes era un campo de texto suelto. El nombre del banco se escribe una
/// sola vez en la vida de la app y termina impreso en cada boleta: que salga
/// "bcp" en una y "Bcp" en otra depende de cómo se tenía el teclado ese día.
/// De una lista sale siempre igual, y se elige de un toque en vez de tipear.
class SelectorBanco extends StatefulWidget {
  const SelectorBanco({
    super.key,
    required this.controlador,
    this.onCambio,
  });

  /// Guarda el nombre final, venga de la lista o escrito a mano.
  final TextEditingController controlador;

  final VoidCallback? onCambio;

  @override
  State<SelectorBanco> createState() => _SelectorBancoState();
}

class _SelectorBancoState extends State<SelectorBanco> {
  /// `null` = todavía no se eligió nada.
  String? _elegido;

  @override
  void initState() {
    super.initState();
    final cargado = widget.controlador.text.trim();
    if (cargado.isEmpty) return;
    // Uno cargado antes de que existiera la lista puede estar escrito de
    // cualquier forma: si coincide con alguno, se muestra elegido.
    _elegido = bancosDelPeru.firstWhere(
      (b) => b.toLowerCase() == cargado.toLowerCase(),
      orElse: () => _otro,
    );
  }

  void _elegir(String? valor) {
    if (valor == null) return;

    setState(() {
      _elegido = valor;
      // Al pasar a "Otro" el campo arranca vacío y no con el banco anterior
      // adentro: se eligió "Otro" justamente porque ese no era.
      widget.controlador.text = valor == _otro ? '' : valor;
    });
    widget.onCambio?.call();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BANCO', style: Tipo.etiqueta),
              const SizedBox(width: Espacio.sm),
              Text(
                'OPCIONAL',
                style: Tipo.etiqueta.copyWith(
                  color: Tono.texto3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.sm),
          InputDecorator(
            decoration: const InputDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _elegido,
                isExpanded: true,
                isDense: true,
                borderRadius: Redondeo.brChico,
                icon: const Icon(Icons.expand_more_rounded,
                    color: Tono.texto3, size: 22),
                hint: Text(
                  'Elige tu banco',
                  style: Tipo.cuerpo.copyWith(color: Tono.texto3),
                ),
                style: Tipo.cuerpo,
                items: [
                  for (final banco in bancosDelPeru)
                    DropdownMenuItem(value: banco, child: Text(banco)),
                  DropdownMenuItem(
                    value: _otro,
                    child: Text('Otro…', style: Tipo.cuerpo),
                  ),
                ],
                onChanged: _elegir,
              ),
            ),
          ),
          // El campo aparece solo, sin tocar nada más: elegir "Otro" ya dijo
          // que hay que escribirlo.
          if (_elegido == _otro) ...[
            const SizedBox(height: Espacio.md),
            Campo(
              etiqueta: 'Nombre del banco',
              controlador: widget.controlador,
              ejemplo: 'Ej. Caja Los Andes',
              autofoco: true,
              textoAccion: TextInputAction.next,
              onCambio: (_) => widget.onCambio?.call(),
            ),
          ],
        ],
      );
}
