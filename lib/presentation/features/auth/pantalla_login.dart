import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/textura.dart';
import '../../../data/local/app_database.dart';

/// Entrada a la app.
///
/// Es una traba de uso, no seguridad real: la app corre entera en el
/// dispositivo, no hay nada del otro lado que proteger.
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

  bool _verClave = false;
  bool _entrando = false;
  bool _claveDeFabrica = false;
  String? _errorAcceso;

  @override
  void initState() {
    super.initState();
    _revisarClaveInicial();
  }

  Future<void> _revisarClaveInicial() async {
    final inicial = await ref.read(authRepoProvider).esClaveInicial();
    if (mounted) setState(() => _claveDeFabrica = inicial);
  }

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_entrando) return;
    if (!_form.currentState!.validate()) return;

    setState(() {
      _entrando = true;
      _errorAcceso = null;
    });

    final auth = ref.read(authRepoProvider);
    final ok = await auth.validarLogin(_usuario.text, _clave.text);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _entrando = false;
        _errorAcceso = 'Usuario o contraseña incorrectos.';
      });
      return;
    }

    await auth.abrirSesion();
    if (mounted) widget.alEntrar();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = ref.watch(negocioProvider).nombre.trim();

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
                  child: EntradaSuave(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Ingresa para continuar', style: Tipo.titulo2),
                          const SizedBox(height: Espacio.xl),
                          Campo(
                            etiqueta: 'Usuario',
                            controlador: _usuario,
                            ejemplo: usuarioInicial,
                            textoAccion: TextInputAction.next,
                            validador: Valida.obligatorio('el usuario'),
                            onCambio: (_) =>
                                setState(() => _errorAcceso = null),
                          ),
                          const SizedBox(height: Espacio.lg),
                          Campo(
                            etiqueta: 'Contraseña',
                            controlador: _clave,
                            oculto: !_verClave,
                            ejemplo: '••••••••',
                            textoAccion: TextInputAction.done,
                            validador: Valida.obligatorio('la contraseña'),
                            onCambio: (_) =>
                                setState(() => _errorAcceso = null),
                            onEnviar: (_) => _entrar(),
                            sufijo: IconButton(
                              onPressed: () =>
                                  setState(() => _verClave = !_verClave),
                              icon: Icon(
                                _verClave
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 21,
                                color: Tono.texto3,
                              ),
                              tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                            ),
                          ),
                          if (_errorAcceso != null) ...[
                            const SizedBox(height: Espacio.lg),
                            _Error(mensaje: _errorAcceso!),
                          ],
                          const SizedBox(height: Espacio.xl),
                          FilledButton(
                            onPressed: _entrando ? null : _entrar,
                            child: _entrando
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
                          if (_claveDeFabrica) ...[
                            const SizedBox(height: Espacio.xl),
                            Panel(
                              color: Tono.oroSuave,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PRIMER INGRESO',
                                    style: Tipo.etiqueta
                                        .copyWith(color: Tono.oroTexto),
                                  ),
                                  const SizedBox(height: Espacio.sm),
                                  Text(
                                    'Usuario $usuarioInicial, contraseña '
                                    '$claveInicial. Cámbiala desde el menú de '
                                    'arriba.',
                                    style: Tipo.secundario
                                        .copyWith(color: Tono.oroTexto),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
