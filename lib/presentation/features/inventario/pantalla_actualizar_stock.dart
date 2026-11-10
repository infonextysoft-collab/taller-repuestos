import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/texto.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/pulsable.dart';
import '../../../domain/entities/repuesto.dart';
import '../../comunes/barra_accion.dart';

/// Corregir el stock de varios repuestos de una sola pasada.
///
/// Es la pantalla para **después de contar el almacén**: se recorre la lista
/// con los dos botones, o se toca el número y se escribe lo que hay, y recién
/// al final se guarda todo junto. Entrar a editar repuesto por repuesto para
/// cambiar un número era abrir y cerrar un formulario quince veces.
///
/// Solo se guardan los que cambiaron: lo que no se tocó no se vuelve a
/// escribir en la base.
class PantallaActualizarStock extends ConsumerStatefulWidget {
  const PantallaActualizarStock({super.key});

  @override
  ConsumerState<PantallaActualizarStock> createState() =>
      _PantallaActualizarStockState();
}

class _PantallaActualizarStockState
    extends ConsumerState<PantallaActualizarStock> {
  final _busqueda = TextEditingController();

  List<Repuesto> _items = const [];

  /// Lo contado, por id. Solo entra el que se tocó.
  final Map<int, int> _nuevos = {};

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final items = await ref.read(inventarioRepoProvider).listar();
    if (!mounted) return;
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  List<Repuesto> get _visibles =>
      _items.where((r) => coincide(r.nombre, _busqueda.text)).toList();

  int _stockDe(Repuesto r) => _nuevos[r.id] ?? r.stock;

  /// Cuántos quedaron distintos de como estaban. Volver al número original
  /// **borra el cambio**: dejar un "1 cambio" que no cambia nada haría dudar
  /// de lo que se está por guardar.
  int get _cambiados =>
      _items.where((r) => _nuevos.containsKey(r.id) && _nuevos[r.id] != r.stock)
          .length;

  void _poner(Repuesto r, int valor) {
    final nuevo = valor < 0 ? 0 : valor;
    setState(() {
      if (nuevo == r.stock) {
        _nuevos.remove(r.id);
      } else {
        _nuevos[r.id!] = nuevo;
      }
    });
  }

  Future<void> _escribir(Repuesto r) async {
    final valor = await _pedirNumero(context, r.nombre, _stockDe(r));
    if (valor != null) _poner(r, valor);
  }

  Future<void> _guardar() async {
    if (_cambiados == 0 || _guardando) return;
    setState(() => _guardando = true);

    final repo = ref.read(inventarioRepoProvider);
    var guardados = 0;

    for (final r in _items) {
      final nuevo = _nuevos[r.id];
      if (nuevo == null || nuevo == r.stock) continue;
      await repo.actualizar(r.copyWith(stock: nuevo));
      guardados++;
    }

    if (!mounted) return;
    ref.read(refrescoInventarioProvider.notifier).state++;
    HapticFeedback.mediumImpact();

    // El aviso lo muestra quien nos abrió: después del pop, este context ya
    // no está montado y el mensaje se perdería.
    Navigator.of(context).pop(guardados);
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;

    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar stock')),
      bottomNavigationBar: BarraAccion(
        texto: _cambiados == 0
            ? 'Guardar'
            : _cambiados == 1
                ? 'Guardar 1 cambio'
                : 'Guardar $_cambiados cambios',
        habilitado: _cambiados > 0 && !_guardando,
        onTap: _guardar,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Espacio.xxl),
        children: [
          Contenido(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lg,
              Espacio.lg,
              Espacio.lg,
              Espacio.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cuenta lo que tienes y deja el número que hay. Lo que no '
                  'toques queda igual.',
                  style: Tipo.secundario,
                ),
                const SizedBox(height: Espacio.lg),
                TextField(
                  controller: _busqueda,
                  onChanged: (_) => setState(() {}),
                  style: Tipo.cuerpo,
                  decoration: const InputDecoration(
                    hintText: 'Buscar repuesto',
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 21, color: Tono.texto3),
                  ),
                ),
              ],
            ),
          ),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.only(top: Espacio.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibles.isEmpty)
            Contenido(
              child: EstadoVacio(
                icono: Icons.inventory_2_rounded,
                titulo: _items.isEmpty
                    ? 'El inventario está vacío'
                    : 'Ningún repuesto coincide',
                detalle: _items.isEmpty
                    ? 'Carga primero lo que tienes.'
                    : 'Prueba con otro nombre.',
              ),
            )
          else
            Contenido(
              child: ListaAgrupada(
                filas: [
                  for (final r in visibles)
                    _FilaStock(
                      repuesto: r,
                      stock: _stockDe(r),
                      cambiado: _nuevos.containsKey(r.id),
                      onMenos: () => _poner(r, _stockDe(r) - 1),
                      onMas: () => _poner(r, _stockDe(r) + 1),
                      onEscribir: () => _escribir(r),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Escribir el conteo de una vez. Con cuarenta y siete unidades, llegar a
/// cuarenta y siete tocando "+" no es una forma de trabajar.
Future<int?> _pedirNumero(
  BuildContext context,
  String nombre,
  int actual,
) async {
  final controlador = TextEditingController(text: '$actual');

  final valor = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(nombre.toUpperCase()),
      content: Campo(
        etiqueta: 'Cuántos hay',
        controlador: controlador,
        autofoco: true,
        teclado: TextInputType.number,
        formateadores: [soloDigitosFormato],
        textoAccion: TextInputAction.done,
        onEnviar: (v) =>
            Navigator.of(context).pop(int.tryParse(v.trim()) ?? actual),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        0,
        Espacio.lg,
        Espacio.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            int.tryParse(controlador.text.trim()) ?? actual,
          ),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );

  controlador.dispose();
  return valor;
}

class _FilaStock extends StatelessWidget {
  const _FilaStock({
    required this.repuesto,
    required this.stock,
    required this.cambiado,
    required this.onMenos,
    required this.onMas,
    required this.onEscribir,
  });

  final Repuesto repuesto;
  final int stock;
  final bool cambiado;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final VoidCallback onEscribir;

  @override
  Widget build(BuildContext context) => FilaLista(
        padding: const EdgeInsets.fromLTRB(
          Espacio.lg,
          Espacio.md,
          Espacio.md,
          Espacio.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repuesto.nombre.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tipo.encabezado,
                  ),
                  if (cambiado) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Antes: ${repuesto.stock}',
                      style: Tipo.nota.copyWith(color: Tono.vinoTexto),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Espacio.sm),
            _Paso(icono: Icons.remove_rounded, onTap: onMenos),
            // El número es el botón para escribirlo: es lo que uno mira
            // mientras cuenta, así que es donde va a tocar.
            Pulsable(
              onTap: onEscribir,
              escala: 0.9,
              semantica: 'Escribir el stock de ${repuesto.nombre}',
              child: Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  '$stock',
                  style: Tipo.monto.copyWith(
                    fontSize: 18,
                    color: cambiado ? Tono.vinoTexto : Tono.texto,
                  ),
                ),
              ),
            ),
            _Paso(icono: Icons.add_rounded, onTap: onMas),
          ],
        ),
      );
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pulsable(
        onTap: onTap,
        escala: 0.88,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Tono.fondo2,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 19, color: Tono.texto),
        ),
      );
}
