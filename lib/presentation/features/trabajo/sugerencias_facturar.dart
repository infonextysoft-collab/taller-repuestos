import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/texto.dart';
import '../../../domain/repositories/trabajos_repository.dart';

/// Las últimas empresas a las que se facturó, debajo de "Facturar a".
///
/// A una empresa se le vuelve a trabajar seguido, y escribir la razón social
/// entera cada vez es donde aparecen las faltas de ortografía que después
/// salen impresas. Mientras se escribe, quedan solo las que coinciden.
class SugerenciasFacturar extends ConsumerWidget {
  const SugerenciasFacturar({
    super.key,
    required this.controlador,
    required this.exceptoId,
    required this.onElegir,
  });

  final TextEditingController controlador;
  final int? exceptoId;
  final ValueChanged<Facturado> onElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recientes =
        ref.watch(facturadosRecientesProvider(exceptoId)).valueOrNull ??
        const <Facturado>[];
    if (recientes.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controlador,
      builder: (context, valor, _) {
        final escrito = normalizar(valor.text);
        final visibles = recientes.where((f) {
          final nombre = normalizar(f.nombre);
          return nombre != escrito &&
              (escrito.isEmpty || nombre.contains(escrito));
        }).toList();

        if (visibles.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: Espacio.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usadas antes', style: Tipo.nota),
              const SizedBox(height: Espacio.sm),
              Wrap(
                spacing: Espacio.sm,
                runSpacing: Espacio.sm,
                children: [
                  for (final f in visibles)
                    _Sugerencia(texto: f.nombre, onTap: () => onElegir(f)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sugerencia extends StatelessWidget {
  const _Sugerencia({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Tono.fondo,
    shape: const StadiumBorder(side: BorderSide(color: Tono.lineaFuerte)),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Container(
        constraints: const BoxConstraints(minHeight: kAreaTactil),
        padding: const EdgeInsets.symmetric(horizontal: Espacio.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 17, color: Tono.texto3),
            const SizedBox(width: Espacio.sm),
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
