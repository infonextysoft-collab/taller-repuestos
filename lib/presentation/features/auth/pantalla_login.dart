import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/texto.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/textura.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/repositories/auth_repository.dart';

/// Entrada a la app.
///
/// Dos caras. Sin correo vinculado, usuario y contraseña como siempre. Con
/// correo, solo la contraseña: la cuenta se muestra a medio tapar, porque esta
/// pantalla la ve cualquiera que levante el teléfono y el correo completo es
/// justo lo que alguien necesitaría para molestar la cuenta desde afuera.
///
/// La cabecera repite el vino y la regla dorada de la bienvenida: la pantalla
/// anterior se levantó y dejó esto debajo, así que tiene que sentirse el mismo
/// lugar y no otra app.
class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key, required this.alEntrar});

  final VoidCallback alEntrar;

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();

  EstadoCuenta? _estado;
  bool _ocupado = false;
  ResultadoAuth? _fallo;

  @override
  void initState() {
    super.initState();
    _leerEstado();
  }

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _leerEstado() async {
    EstadoCuenta estado;
    ResultadoAuth? fallo;

    try {
      estado = await ref.read(authRepoProvider).estado();
    } catch (_) {
      // Sin poder leer la cuenta se muestra el formulario de siempre y se dice
      // qué pasó: una pantalla vacía no deja ni intentar.
      estado = const EstadoCuenta(usuario: usuarioInicial);
      fallo = const ResultadoAuth.error(
        'No se pudo leer el acceso de este teléfono. Cierra la app y vuelve a '
        'abrirla.',
      );
    }

    if (!mounted) return;
    setState(() {
      _estado = estado;
      _fallo = fallo;
    });
  }

  /// Algo reventó por debajo. El botón no puede quedar girando para siempre.
  void _falloInesperado() {
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _fallo = const ResultadoAuth.error(
        'Algo falló al entrar. Vuelve a probar.',
      );
    });
  }

  Future<void> _entrar() async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) return;

    setState(() {
      _ocupado = true;
      _fallo = null;
    });

    final auth = ref.read(authRepoProvider);
    final ResultadoAuth resultado;
    try {
      resultado = await auth.entrar(
        usuario: _usuario.text,
        clave: _clave.text,
      );
    } catch (_) {
      _falloInesperado();
      return;
    }

    if (!mounted) return;

    if (!resultado.correcto) {
      setState(() {
        _ocupado = false;
        _fallo = resultado;
      });
      return;
    }

    await _pasar(auth);
  }

  Future<void> _pasar(AuthRepository auth) async {
    try {
      await auth.abrirSesion();
    } catch (_) {
      _falloInesperado();
      return;
    }
    if (!mounted) return;
    ref.invalidate(estadoCuentaProvider);
    widget.alEntrar();
  }

  /// La cuenta de correo ya no acepta la última contraseña de este teléfono.
  ///
  /// No se deja a nadie afuera por eso: sin señal esa contraseña entraría
  /// igual. Se le dice qué pasa y se le ofrece seguir sin el correo.
  Future<void> _seguirSinCorreo() async {
    final seguro = await confirmar(
      context,
      titulo: '¿Seguir sin el correo?',
      mensaje: 'Entras con la contraseña de siempre y este teléfono deja de '
          'usar el correo para recuperarla. Puedes volver a vincularlo desde '
          'el menú del negocio.',
    );
    if (!seguro || !mounted) return;

    setState(() => _ocupado = true);

    final auth = ref.read(authRepoProvider);
    final ResultadoAuth resultado;
    try {
      resultado = await auth.desvincularCorreo(_clave.text);
    } catch (_) {
      _falloInesperado();
      return;
    }
    if (!mounted) return;

    if (!resultado.correcto) {
      setState(() {
        _ocupado = false;
        _fallo = resultado;
      });
      return;
    }

    await _pasar(auth);
  }

  Future<void> _olvide() async {
    final correo = _estado?.correo;
    if (_ocupado || correo == null) return;

    final seguro = await confirmar(
      context,
      titulo: '¿Te mandamos un enlace?',
      mensaje: 'Va a ${ocultarCorreo(correo)}. Ábrelo, pon una contraseña '
          'nueva y entra con ella aquí.',
    );
    if (!seguro || !mounted) return;

    setState(() => _ocupado = true);

    ResultadoAuth resultado;
    try {
      resultado = await ref.read(authRepoProvider).enviarRecuperacion();
    } catch (_) {
      resultado = const ResultadoAuth.error(
        'Algo falló al enviar el enlace. Vuelve a probar.',
      );
    }

    if (!mounted) return;
    setState(() => _ocupado = false);

    if (!resultado.correcto) {
      mostrarAviso(context, resultado.error ?? '', problema: true);
      return;
    }

    await informar(
      context,
      titulo: 'Revisa tu correo',
      mensaje: resultado.aviso ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = ref.watch(negocioProvider).nombre.trim();
    final estado = _estado;

    return Scaffold(
      backgroundColor: Tono.vinoHondo,
      body: Column(
        children: [
          _Cabecera(nombre: nombre.isEmpty ? 'MS' : nombre),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Tono.fondo,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Redondeo.grande),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: Espacio.xxl),
                child: Contenido(
                  ancho: Ancho.acciones,
                  padding: const EdgeInsets.fromLTRB(
                    Espacio.xl,
                    Espacio.xxl,
                    Espacio.xl,
                    Espacio.xl,
                  ),
                  // Lo que tarda en leerse la cuenta son milisegundos. El
                  // formulario entra recién ahí, para no dibujar "Usuario" y
                  // cambiarlo de golpe cuando resulta que hay correo.
                  child: estado == null
                      ? const SizedBox(height: 280)
                      : EntradaSuave(child: _formulario(estado)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario(EstadoCuenta estado) {
    final fallo = _fallo;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            estado.conCorreo
                ? 'Ingresa tu contraseña'
                : 'Ingresa para continuar',
            style: Tipo.titulo2,
          ),
          const SizedBox(height: Espacio.xl),
          if (estado.conCorreo)
            _Cuenta(correo: estado.correo!)
          else
            Campo(
              etiqueta: 'Usuario',
              controlador: _usuario,
              ejemplo: usuarioInicial,
              textoAccion: TextInputAction.next,
              validador: Valida.obligatorio('el usuario'),
              onCambio: (_) => setState(() => _fallo = null),
            ),
          const SizedBox(height: Espacio.lg),
          Campo(
            etiqueta: 'Contraseña',
            controlador: _clave,
            oculto: true,
            ejemplo: '••••••••',
            textoAccion: TextInputAction.done,
            validador: Valida.obligatorio('la contraseña'),
            onCambio: (_) => setState(() => _fallo = null),
            onEnviar: (_) => _entrar(),
          ),
          if (fallo != null) ...[
            const SizedBox(height: Espacio.lg),
            _Error(mensaje: fallo.error ?? ''),
            if (fallo.motivo == MotivoAuth.cuentaRechazaClave) ...[
              const SizedBox(height: Espacio.md),
              OutlinedButton(
                onPressed: _ocupado ? null : _seguirSinCorreo,
                child: const Text('Seguir sin el correo'),
              ),
            ],
          ],
          const SizedBox(height: Espacio.xl),
          FilledButton(
            onPressed: _ocupado ? null : _entrar,
            child: _ocupado
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Entrar'),
          ),
          if (estado.conCorreo && estado.nubeDisponible) ...[
            const SizedBox(height: Espacio.md),
            TextButton(
              onPressed: _ocupado ? null : _olvide,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ],
        ],
      ),
    );
  }
}

/// La cuenta con la que se entra, a medio tapar y sin poder editarla.
class _Cuenta extends StatelessWidget {
  const _Cuenta({required this.correo});

  final String correo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Espacio.lg,
          vertical: Espacio.md,
        ),
        decoration: BoxDecoration(
          color: Tono.fondo2,
          borderRadius: Redondeo.brChico,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: Tono.texto3,
            ),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUENTA', style: Tipo.etiqueta),
                  const SizedBox(height: 2),
                  Text(
                    ocultarCorreo(correo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.cuerpo,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// La cabecera del login: el emblema centrado sobre la banda de marca.
///
/// El logo va al centro y grande porque es lo único que hay arriba. En la barra
/// del día a día vive chiquito a un costado —ahí lo que importa es el trabajo—,
/// pero esta es la pantalla donde la app se presenta.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Tono.vino, Tono.vinoNoche],
            stops: [0, 0.92],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: EstriasDiagonales()),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.xl,
                  Espacio.xl,
                  Espacio.xl,
                  Espacio.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Emblema(),
                    const SizedBox(height: Espacio.lg),
                    Text(
                      nombre.toUpperCase(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Tipo.display.copyWith(
                        color: Tono.textoInverso,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: Espacio.md),
                    Container(
                      width: 64,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Tono.oroClaro,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Espacio.md),
        decoration: BoxDecoration(
          color: Tono.vinoSuave,
          borderRadius: Redondeo.brChico,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 19, color: Tono.vino),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Text(
                mensaje,
                style: Tipo.secundario.copyWith(
                  color: Tono.vino,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
