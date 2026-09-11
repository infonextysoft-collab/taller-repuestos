import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/movimiento.dart';
import '../../core/theme/tipografia.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/foto.dart';
import '../../core/widgets/pulsable.dart';

/// Las fotos de un paso: dos botones grandes arriba y una grilla debajo.
///
/// "Tomar foto" es lo primero y ocupa el ancho: en el sitio se saca el
/// celular, se fotografía cómo llega el equipo y cómo queda, y recién después
/// se completa el resto con calma.
class GaleriaFotos extends ConsumerStatefulWidget {
  const GaleriaFotos({
    super.key,
    required this.fotos,
    required this.onCambio,
    this.bloqueado = false,
  });

  final List<Foto> fotos;
  final ValueChanged<List<Foto>> onCambio;
  final bool bloqueado;

  @override
  ConsumerState<GaleriaFotos> createState() => _GaleriaFotosState();
}

class _GaleriaFotosState extends ConsumerState<GaleriaFotos> {
  bool _trabajando = false;

  Future<void> _agregar({required bool conCamara}) async {
    if (_trabajando) return;
    setState(() => _trabajando = true);

    final servicio = ref.read(servicioFotosProvider);
    final foto = conCamara ? await servicio.tomar() : await servicio.elegir();

    if (!mounted) return;
    setState(() => _trabajando = false);

    if (foto != null) widget.onCambio([...widget.fotos, foto]);
  }

  void _quitar(int indice) {
    widget.onCambio([...widget.fotos]..removeAt(indice));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.bloqueado) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _trabajando ? null : () => _agregar(conCamara: true),
                  icon: _trabajando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.photo_camera_rounded, size: 20),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: Espacio.md),
              // Solo el ícono, sin la palabra "Subir": el botón quedaba tan
              // angosto que la partía en dos renglones ("Subi/r") y se veía
              // roto. El ícono de foto con un "+" ya se entiende solo, y así
              // "Tomar foto" —que es lo que se toca nueve de cada diez veces—
              // se queda con todo el ancho.
              Tooltip(
                message: 'Subir una foto de la galería',
                child: SizedBox(
                  width: 62,
                  height: 54,
                  child: OutlinedButton(
                    onPressed:
                        _trabajando ? null : () => _agregar(conCamara: false),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 22,
                      semanticLabel: 'Subir una foto de la galería',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.lg),
        ],
        if (widget.fotos.isEmpty)
          Text(
            widget.bloqueado
                ? 'No se cargaron fotos.'
                : 'Todavía no hay fotos. Este paso se puede saltar.',
            style: Tipo.secundario,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 4 / 3,
              mainAxisSpacing: Espacio.md,
              crossAxisSpacing: Espacio.md,
            ),
            itemBuilder: (context, i) => _Miniatura(
              foto: widget.fotos[i],
              onQuitar: widget.bloqueado ? null : () => _quitar(i),
              onVer: () => _verGrande(context, widget.fotos[i]),
            ),
          ),
      ],
    );
  }

  void _verGrande(BuildContext context, Foto foto) {
    final bytes = foto.bytes;
    if (bytes.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: const Color(0xF21B1A18),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.lg),
          child: InteractiveViewer(
            child: Center(
              child: ClipRRect(
                borderRadius: Redondeo.brNormal,
                child: Image.memory(bytes),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto, required this.onVer, this.onQuitar});

  final Foto foto;
  final VoidCallback onVer;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    // En la grilla alcanza con la version chica; la completa se abre al tocar.
    final Uint8List? bytes = foto.paraLista.isEmpty ? null : foto.paraLista;

    return EntradaSuave(
      desplazamiento: 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Pulsable(
            onTap: onVer,
            escala: 0.97,
            child: ClipRRect(
              borderRadius: Redondeo.brChico,
              child: bytes == null
                  ? const ColoredBox(
                      color: Tono.fondo2,
                      child: Icon(Icons.broken_image_rounded,
                          color: Tono.texto3),
                    )
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          if (onQuitar != null)
            Positioned(
              top: Espacio.sm,
              right: Espacio.sm,
              child: Pulsable(
                onTap: onQuitar,
                escala: 0.85,
                semantica: 'Quitar foto',
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xCC1B1A18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 17, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
