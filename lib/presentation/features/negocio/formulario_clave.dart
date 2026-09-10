import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/campo.dart';

/// Cambio de contraseña. Exige la actual para que nadie la cambie con la
/// sesión ajena abierta.
class FormularioClave extends ConsumerStatefulWidget {
  const FormularioClave({super.key, required this.onListo});

  final VoidCallback onListo;

  @override
  ConsumerState<FormularioClave> createState() => _FormularioClaveState();
}

class _FormularioClaveState extends ConsumerState<FormularioClave> {
  final _form = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final resultado = await ref
        .read(authRepoProvider)
        .cambiarClave(_actual.text, _nueva.text);

    if (!mounted) return;

    if (!resultado.correcto) {
      setState(() {
        _guardando = false;
        _error = resultado.error;
      });
      return;
    }

    mostrarAviso(context, 'Contraseña cambiada.');
    widget.onListo();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.xl,
          0,
          Espacio.xl,
          Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Campo(
              etiqueta: 'Contraseña actual',
              controlador: _actual,
              oculto: true,
              autofoco: true,
              textoAccion: TextInputAction.next,
              validador: Valida.obligatorio('la contraseña actual'),
            ),
            const SizedBox(height: Espacio.lg),
            Campo(
              etiqueta: 'Nueva',
              controlador: _nueva,
              oculto: true,
              ayuda: 'Al menos 4 caracteres.',
              textoAccion: TextInputAction.next,
              validador: Valida.todos([
                Valida.obligatorio('la contraseña nueva'),
                Valida.minimo(4, 'La contraseña'),
              ]),
            ),
            const SizedBox(height: Espacio.lg),
            Campo(
              etiqueta: 'Repetir la nueva',
              controlador: _repetir,
              oculto: true,
              textoAccion: TextInputAction.done,
              onEnviar: (_) => _guardar(),
              validador: (valor) =>
                  valor == _nueva.text ? null : 'No coincide con la nueva.',
            ),
            if (_error != null) ...[
              const SizedBox(height: Espacio.lg),
              Text(
                _error!,
                style: const TextStyle(
                  color: Tono.vino,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: Espacio.xl),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: const Text('Cambiar contraseña'),
            ),
          ],
        ),
        ),
      );
}
