import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../domain/repositories/auth_repository.dart';

/// La recuperación de contraseña por correo, desde adentro de la app.
///
/// Tiene tres caras según cómo esté el teléfono:
///
///   - **Con la contraseña de fábrica**: primero hay que cambiarla. Esa está
///     escrita en las instrucciones, y una cuenta de correo con ella la podría
///     abrir cualquiera.
///   - **Sin correo**: el formulario para vincular uno.
///   - **Con correo**: cuál es, **completo**. Acá ya se entró, y un error de
///     tipeo solo se descubre leyéndolo entero. Y cómo desvincularlo, que
///     funciona aunque esta instalación no tenga Firebase.
class VentanaCorreo extends ConsumerWidget {
  const VentanaCorreo({
    super.key,
    required this.onListo,
    required this.onCambiarClave,
  });

  final VoidCallback onListo;

  /// Cierra esta ventana y abre la de cambiar contraseña.
  final VoidCallback onCambiarClave;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espacio.xl,
          0,
          Espacio.xl,
          Espacio.xl,
        ),
        child: ref.watch(estadoCuentaProvider).when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Espacio.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'No se pudo leer la cuenta: $error',
                style: Tipo.secundario,
              ),
              data: (cuenta) {
                if (cuenta.conCorreo) {
                  return _Vinculado(
                    correo: cuenta.correo!,
                    conNube: cuenta.nubeDisponible,
                    onListo: onListo,
                  );
                }
                if (cuenta.claveDeFabrica) {
                  return _PrimeroLaClave(onCambiarClave: onCambiarClave);
                }
                return _Vincular(
                  onListo: onListo,
                  onCambiarClave: onCambiarClave,
                );
              },
            ),
      );
}

class _PrimeroLaClave extends StatelessWidget {
  const _PrimeroLaClave({required this.onCambiarClave});

  final VoidCallback onCambiarClave;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Todavía tienes la contraseña de fábrica. Esa está escrita en las '
            'instrucciones de la app, así que una cuenta de correo con ella la '
            'podría abrir cualquiera. Cámbiala primero y vuelve aquí.',
            style: Tipo.secundario,
          ),
          const SizedBox(height: Espacio.xl),
          FilledButton(
            onPressed: onCambiarClave,
            child: const Text('Cambiar contraseña'),
          ),
        ],
      );
}

/// Si la ventana se cerró mientras se esperaba, igual se avisa del cambio:
/// el menú no puede quedar mostrando lo de antes.
///
/// Si sigue abierta no hace falta: la invalida quien la abrió, al cerrarla, y
/// así la ventana no cambia de cara mientras se va.
void _avisarSiYaCerro(
  State estado,
  ProviderContainer contenedor,
  ResultadoAuth resultado,
) {
  if (!estado.mounted && resultado.correcto) {
    contenedor.invalidate(estadoCuentaProvider);
  }
}

/* --------------------------------------------------------------- vincular */

class _Vincular extends ConsumerStatefulWidget {
  const _Vincular({required this.onListo, required this.onCambiarClave});

  final VoidCallback onListo;
  final VoidCallback onCambiarClave;

  @override
  ConsumerState<_Vincular> createState() => _VincularState();
}

class _VincularState extends ConsumerState<_Vincular> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _claveApp = TextEditingController();
  final _claveCuenta = TextEditingController();

  /// El correo ya tiene cuenta con otra contraseña: se pide también esa.
  bool _pideCuenta = false;

  /// El correo que ya se leyó entero y se confirmó, para no volver a
  /// preguntarlo al pedir la contraseña de la cuenta.
  String? _confirmado;

  bool _ocupado = false;
  String? _error;
  MotivoAuth? _motivo;

  /// Lo que se arregla cambiando la contraseña: se ofrece el botón ahí mismo.
  bool get _ofreceCambiarClave =>
      _motivo == MotivoAuth.claveCorta || _motivo == MotivoAuth.claveDeFabrica;

  @override
  void dispose() {
    _correo.dispose();
    _claveApp.dispose();
    _claveCuenta.dispose();
    super.dispose();
  }

  Future<void> _vincular() async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) return;

    final correo = _correo.text.trim().toLowerCase();

    // Se lee entero antes de mandarlo: con un error de tipeo, los enlaces
    // terminan yendo a otra parte.
    if (correo != _confirmado) {
      final bien = await confirmar(
        context,
        titulo: '¿Está bien escrito?',
        mensaje: '$correo\n\nA esta dirección van a llegar los enlaces para '
            'recuperar la contraseña.',
      );
      if (!bien || !mounted) return;
      _confirmado = correo;
    }

    setState(() {
      _ocupado = true;
      _error = null;
      _motivo = null;
    });

    final contenedor = ProviderScope.containerOf(context, listen: false);
    ResultadoAuth resultado;
    try {
      resultado = await contenedor.read(authRepoProvider).vincularCorreo(
            correo: correo,
            claveApp: _claveApp.text,
            claveCuenta: _pideCuenta ? _claveCuenta.text : null,
          );
    } catch (_) {
      resultado = const ResultadoAuth.error(
        'Algo falló al vincular el correo. Vuelve a probar.',
      );
    }

    _avisarSiYaCerro(this, contenedor, resultado);
    if (!mounted) return;

    if (resultado.correcto) {
      await informar(
        context,
        titulo: 'Correo vinculado',
        mensaje: resultado.aviso ?? '',
      );
      if (mounted) widget.onListo();
      return;
    }

    setState(() {
      _ocupado = false;
      _error = resultado.error;
      _motivo = resultado.motivo;
      if (resultado.motivo == MotivoAuth.cuentaConOtraClave) {
        _pideCuenta = true;
      }
    });
  }

  /// Para quien tiene la cuenta pero no se acuerda de su contraseña.
  Future<void> _mandarEnlace() async {
    if (_ocupado) return;

    setState(() => _ocupado = true);

    ResultadoAuth resultado;
    try {
      resultado = await ref
          .read(authRepoProvider)
          .enviarRecuperacion(correo: _correo.text);
    } catch (_) {
      resultado = const ResultadoAuth.error(
        'Algo falló al enviar el enlace. Vuelve a probar.',
      );
    }

    if (!mounted) return;
    setState(() => _ocupado = false);

    if (!resultado.correcto) {
      setState(() => _error = resultado.error);
      return;
    }

    await informar(
      context,
      titulo: 'Revisa tu correo',
      mensaje: '${resultado.aviso ?? ''}\n\nCon la contraseña nueva, vuelve '
          'aquí y escríbela como la de tu cuenta.',
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // Mientras se habla con la cuenta no se cierra: si no, el resultado
        // llega a una ventana que ya no está y el aviso se pierde.
        canPop: !_ocupado,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Campo(
                etiqueta: 'Correo',
                controlador: _correo,
                ejemplo: 'tucorreo@gmail.com',
                teclado: TextInputType.emailAddress,
                autofoco: true,
                habilitado: !_pideCuenta,
                textoAccion: TextInputAction.next,
                validador: Valida.todos([
                  Valida.obligatorio('el correo'),
                  Valida.email(),
                ]),
              ),
              const SizedBox(height: Espacio.lg),
              Campo(
                etiqueta: 'Contraseña de esta app',
                controlador: _claveApp,
                oculto: true,
                habilitado: !_pideCuenta,
                textoAccion:
                    _pideCuenta ? TextInputAction.next : TextInputAction.done,
                onEnviar: _pideCuenta ? null : (_) => _vincular(),
                validador: Valida.obligatorio('la contraseña'),
              ),
              if (_pideCuenta) ...[
                const SizedBox(height: Espacio.lg),
                Campo(
                  etiqueta: 'Contraseña de tu cuenta de correo',
                  controlador: _claveCuenta,
                  oculto: true,
                  autofoco: true,
                  ayuda: 'Desde ahora será también la de esta app: una sola '
                      'para recordar.',
                  textoAccion: TextInputAction.done,
                  onEnviar: (_) => _vincular(),
                  validador: Valida.obligatorio('la contraseña de la cuenta'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _ocupado ? null : _mandarEnlace,
                    child:
                        const Text('¿No la recuerdas? Te mandamos un enlace'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: Espacio.lg),
                _TextoError(_error!),
              ],
              if (_ofreceCambiarClave) ...[
                const SizedBox(height: Espacio.md),
                OutlinedButton(
                  onPressed: widget.onCambiarClave,
                  child: const Text('Cambiar contraseña'),
                ),
              ],
              const SizedBox(height: Espacio.xl),
              FilledButton(
                onPressed: _ocupado ? null : _vincular,
                child: _ocupado
                    ? const _Girando()
                    : const Text('Vincular correo'),
              ),
            ],
          ),
        ),
      );
}

/* -------------------------------------------------------------- vinculado */

class _Vinculado extends ConsumerStatefulWidget {
  const _Vinculado({
    required this.correo,
    required this.conNube,
    required this.onListo,
  });

  final String correo;

  /// Sin Firebase en esta instalación no hay enlace de recuperación, pero
  /// desvincular sí funciona: es local.
  final bool conNube;

  final VoidCallback onListo;

  @override
  ConsumerState<_Vinculado> createState() => _VinculadoState();
}

class _VinculadoState extends ConsumerState<_Vinculado> {
  final _form = GlobalKey<FormState>();
  final _clave = TextEditingController();

  bool _desvinculando = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _desvincular() async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) return;

    setState(() {
      _ocupado = true;
      _error = null;
    });

    final contenedor = ProviderScope.containerOf(context, listen: false);
    ResultadoAuth resultado;
    try {
      resultado =
          await contenedor.read(authRepoProvider).desvincularCorreo(_clave.text);
    } catch (_) {
      resultado = const ResultadoAuth.error(
        'Algo falló al desvincular. Vuelve a probar.',
      );
    }

    _avisarSiYaCerro(this, contenedor, resultado);
    if (!mounted) return;

    if (!resultado.correcto) {
      setState(() {
        _ocupado = false;
        _error = resultado.error;
      });
      return;
    }

    mostrarAviso(context, 'Correo desvinculado.');
    widget.onListo();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_ocupado,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('VINCULADO A', style: Tipo.etiqueta),
            const SizedBox(height: Espacio.sm),
            Text(widget.correo, style: Tipo.encabezado),
            const SizedBox(height: Espacio.md),
            Text(
              widget.conNube
                  ? 'Si olvidas la contraseña, en la pantalla de ingreso toca '
                      '"¿Olvidaste tu contraseña?" y te llega un enlace a este '
                      'correo. Si está mal escrito, desvincúlalo y ponlo de '
                      'nuevo.'
                  : 'Esta instalación no puede conectarse a la cuenta de '
                      'correo, así que por ahora no hay enlace de recuperación. '
                      'Si desvinculas el correo, puedes cambiar la contraseña '
                      'solo en este teléfono.',
              style: Tipo.secundario,
            ),
            const SizedBox(height: Espacio.xl),
            if (!_desvinculando)
              OutlinedButton(
                onPressed: () => setState(() => _desvinculando = true),
                child: const Text('Desvincular este correo'),
              )
            else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Campo(
                      etiqueta: 'Contraseña de esta app',
                      controlador: _clave,
                      oculto: true,
                      autofoco: true,
                      textoAccion: TextInputAction.done,
                      onEnviar: (_) => _desvincular(),
                      validador: Valida.obligatorio('la contraseña'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Espacio.lg),
                      _TextoError(_error!),
                    ],
                    const SizedBox(height: Espacio.lg),
                    FilledButton(
                      onPressed: _ocupado ? null : _desvincular,
                      child: _ocupado
                          ? const _Girando()
                          : const Text('Desvincular'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _TextoError extends StatelessWidget {
  const _TextoError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) => Text(
        mensaje,
        style: const TextStyle(
          color: Tono.vino,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// Con mala señal esto tarda: un botón solo gris parece colgado.
class _Girando extends StatelessWidget {
  const _Girando();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
