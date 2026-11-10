import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/config/negocio_fijo.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/campo_documento.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/negocio.dart';
import '../../comunes/barra_accion.dart';
import 'selector_banco.dart';

/// Los datos del emisor: lo que sale impreso en la cabecera de cada documento.
///
/// Tiene **dos modos**. Al entrar se ve la ficha ya guardada, tal como se
/// imprime; el formulario aparece recién al tocar "Editar". Antes se abría
/// siempre en modo formulario, y eso hacía que consultar un dato se sintiera
/// como volver a llenar un trámite.
///
/// La vista de lectura es una **maqueta del encabezado real** del documento.
/// Así el "esto es lo que va impreso arriba" no hace falta escribirlo: se ve.
class PantallaNegocio extends ConsumerStatefulWidget {
  const PantallaNegocio({super.key});

  @override
  ConsumerState<PantallaNegocio> createState() => _PantallaNegocioState();
}

class _PantallaNegocioState extends ConsumerState<PantallaNegocio> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _ruc = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _banco = TextEditingController();
  final _cuenta = TextEditingController();
  final _cci = TextEditingController();
  final _yape = TextEditingController();

  /// `null` = todavía no se eligió modo.
  ///
  /// Se deja sin decidir a propósito: los datos llegan de la base un instante
  /// después de abrir la pantalla, y fijarlo en `initState` hacía que **siempre**
  /// se entrara al formulario, porque en ese momento el nombre todavía estaba
  /// vacío. Se resuelve en `build`, ya con los datos.
  bool? _editando;
  bool _hayCambios = false;

  @override
  void initState() {
    super.initState();
    _sembrar(ref.read(negocioProvider));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ruc.dispose();
    _direccion.dispose();
    _telefono.dispose();
    _email.dispose();
    _banco.dispose();
    _cuenta.dispose();
    _cci.dispose();
    _yape.dispose();
    super.dispose();
  }

  void _sembrar(Negocio n) {
    _nombre.text = n.nombre;
    _ruc.text = n.ruc;
    _direccion.text = n.direccion;
    _telefono.text = n.telefono;
    _email.text = n.email;
    _banco.text = n.banco;
    _cuenta.text = n.cuenta;
    _cci.text = n.cci;
    _yape.text = n.yape;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) {
      mostrarAviso(context, 'Revisa los campos marcados.', problema: true);
      return;
    }

    await ref.read(negocioProvider.notifier).guardar(Negocio(
          nombre: _nombre.text.trim(),
          ruc: _ruc.text.trim(),
          direccion: _direccion.text.trim(),
          telefono: _telefono.text.trim(),
          email: _email.text.trim(),
          banco: _banco.text.trim(),
          cuenta: _cuenta.text.trim(),
          cci: _cci.text.trim(),
          yape: _yape.text.trim(),
        ));

    if (!mounted) return;
    setState(() {
      _hayCambios = false;
      _editando = false;
    });
    mostrarAviso(context, 'Datos guardados.');
  }

  void _cancelar() {
    _sembrar(ref.read(negocioProvider));
    setState(() {
      _hayCambios = false;
      _editando = false;
    });
  }

  /// Sin nombre no hay ficha que mostrar: la primera vez se entra escribiendo.
  bool _modoEdicion(Negocio n) => _editando ?? n.nombre.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioProvider);

    // Los datos llegan de la base un instante después de arrancar. Se copian a
    // los campos cuando llegan, pero nunca encima de algo que se esté
    // escribiendo.
    ref.listen(negocioProvider, (_, ahora) {
      if (!_hayCambios) _sembrar(ahora);
    });

    final editando = _modoEdicion(negocio);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Negocio'),
        actions: [
          if (editando && negocio.nombre.trim().isNotEmpty)
            TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
        ],
      ),
      body: editando ? _formulario() : _ficha(negocio),
      bottomNavigationBar: editando
          ? BarraAccion(
              texto: 'Guardar datos',
              habilitado: _hayCambios,
              onTap: _guardar,
            )
          : BarraAccion(
              texto: 'Editar datos',
              onTap: () => setState(() => _editando = true),
            ),
    );
  }

  /* ------------------------------------------------------------- lectura */

  Widget _ficha(Negocio n) => ListView(
        padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
        children: [
          Contenido(
            ancho: Ancho.acciones,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ASÍ SALE EN EL DOCUMENTO', style: Tipo.etiqueta),
                const SizedBox(height: Espacio.md),
                _Membrete(negocio: n),
                const SizedBox(height: Espacio.xl),
                ListaAgrupada(
                  filas: [
                    _Dato('RUC', n.ruc, falta: n.ruc.trim().isEmpty),
                    _Dato('Dirección', n.direccion,
                        falta: n.direccion.trim().isEmpty),
                    _Dato('Teléfono', n.telefono,
                        falta: n.telefono.trim().isEmpty),
                    _Dato('Email', n.email, opcional: true),
                  ],
                ),
                const SizedBox(height: Espacio.xl),
                Text('PARA COBRAR', style: Tipo.etiqueta),
                const SizedBox(height: Espacio.md),
                ListaAgrupada(
                  filas: [
                    _Dato('Banco', n.banco, opcional: true),
                    _Dato('Cuenta', n.cuenta, opcional: true),
                    _Dato('CCI', n.cci, opcional: true),
                    _Dato('Yape / Plin', n.yape, opcional: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  /* ---------------------------------------------------------- formulario */

  Widget _formulario() => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(top: Espacio.lg, bottom: Espacio.xxl),
          children: [
            Contenido(
              ancho: Ancho.acciones,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Campo(
                    etiqueta: 'Nombre',
                    controlador: _nombre,
                    ejemplo: 'Cómo se llama el taller',
                    textoAccion: TextInputAction.next,
                    validador: Valida.todos([
                      Valida.obligatorio('el nombre del negocio'),
                      Valida.minimo(3, 'El nombre'),
                    ]),
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  CampoDocumento(
                    controlador: _ruc,
                    etiqueta: 'RUC',
                    soloRuc: true,
                    obligatorio: true,
                    habilitado: kRucFijo.isEmpty,
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  if (kRucFijo.isNotEmpty) ...[
                    const SizedBox(height: Espacio.xs),
                    Text(
                      'El RUC viene fijo en la app y no se puede cambiar.',
                      style: Tipo.nota,
                    ),
                  ],
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Dirección',
                    controlador: _direccion,
                    ejemplo: 'Va debajo del nombre en el documento',
                    textoAccion: TextInputAction.next,
                    validador: Valida.obligatorio('la dirección'),
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Teléfono',
                    controlador: _telefono,
                    ejemplo: '999999999',
                    teclado: TextInputType.phone,
                    textoAccion: TextInputAction.next,
                    validador: Valida.todos([
                      Valida.obligatorio('el teléfono'),
                      Valida.telefono(),
                    ]),
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Email',
                    controlador: _email,
                    ejemplo: 'taller@correo.com',
                    opcional: true,
                    teclado: TextInputType.emailAddress,
                    textoAccion: TextInputAction.done,
                    validador: Valida.email(),
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.xxl),
                  const Divider(height: 1),
                  const SizedBox(height: Espacio.xxl),
                  Text('PARA COBRAR', style: Tipo.etiqueta),
                  const SizedBox(height: Espacio.sm),
                  Text(
                    'Sale al pie de la nota de venta y se copia al compartirla, para '
                    'no tener que buscar el número cada vez. Lo que dejes '
                    'vacío no se imprime.',
                    style: Tipo.secundario,
                  ),
                  const SizedBox(height: Espacio.lg),
                  SelectorBanco(
                    controlador: _banco,
                    onCambio: () => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Número de cuenta',
                    controlador: _cuenta,
                    ejemplo: '191-0123456-0-12',
                    opcional: true,
                    textoAccion: TextInputAction.next,
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'CCI',
                    controlador: _cci,
                    ejemplo: '00219100123456012',
                    ayuda: 'El interbancario: sin él no te pueden transferir '
                        'desde otro banco.',
                    opcional: true,
                    textoAccion: TextInputAction.next,
                    onCambio: (_) => setState(() => _hayCambios = true),
                  ),
                  const SizedBox(height: Espacio.lg),
                  Campo(
                    etiqueta: 'Yape / Plin',
                    controlador: _yape,
                    ejemplo: '999888777',
                    teclado: TextInputType.phone,
                    opcional: true,
                    textoAccion: TextInputAction.done,
                    onCambio: (_) => setState(() => _hayCambios = true),
                    onEnviar: (_) => _guardar(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// El encabezado del documento, en chico.
class _Membrete extends StatelessWidget {
  const _Membrete({required this.negocio});

  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final n = negocio;

    return Container(
      padding: const EdgeInsets.all(Espacio.xl),
      decoration: const BoxDecoration(
        color: Tono.fondo,
        borderRadius: Redondeo.brNormal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/img/logo.png',
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.bolt_rounded, color: Tono.vino, size: 32),
              ),
              const SizedBox(width: Espacio.md),
              Expanded(
                child: Text(
                  n.nombre.trim().isEmpty ? 'Sin nombre' : n.nombre.trim(),
                  maxLines: 2,
                  style: Tipo.titulo2,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.md),
          Container(height: 2, color: Tono.vino),
          const SizedBox(height: Espacio.md),
          Text(
            [
              if (n.ruc.trim().isNotEmpty) 'RUC ${n.ruc.trim()}',
              if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
              if (n.telefono.trim().isNotEmpty) 'Tel. ${n.telefono.trim()}',
              if (n.email.trim().isNotEmpty) n.email.trim(),
            ].join('   ·   '),
            style: Tipo.nota,
          ),
        ],
      ),
    );
  }
}

/// Una fila de la ficha. Marca en vino lo que falta y todavía tiene que ir.
class _Dato extends StatelessWidget {
  const _Dato(
    this.etiqueta,
    this.valor, {
    this.falta = false,
    this.opcional = false,
  });

  final String etiqueta;
  final String valor;
  final bool falta;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final vacio = valor.trim().isEmpty;

    return FilaLista(
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(etiqueta, style: Tipo.secundario),
          ),
          Expanded(
            child: Text(
              vacio ? (opcional ? 'Sin cargar' : 'Falta') : valor.trim(),
              textAlign: TextAlign.end,
              style: vacio
                  ? Tipo.cuerpo.copyWith(
                      color: falta ? Tono.vinoTexto : Tono.texto3,
                    )
                  : Tipo.cuerpo,
            ),
          ),
        ],
      ),
    );
  }
}
