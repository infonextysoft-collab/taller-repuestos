import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/recordatorio.dart';
import 'formulario_recordatorio.dart';
import 'tarjeta_aviso.dart';

/// Lo que se puede hacer con un aviso. Viven acá porque se hacen igual desde
/// las tres pantallas, y un "Eliminar" que pregunte distinto según desde dónde
/// se tocó no se puede aprender.
void refrescarAvisos(WidgetRef ref) {
  ref.read(refrescoRecordatoriosProvider.notifier).state++;
  ref.invalidate(vencidosProvider);
}

Future<void> nuevoAviso(BuildContext context, WidgetRef ref) =>
    _abrirFormulario(context, ref, null);

Future<void> _abrirFormulario(
  BuildContext context,
  WidgetRef ref,
  Recordatorio? recordatorio,
) async {
  final guardado = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => FormularioRecordatorio(recordatorio: recordatorio),
    ),
  );

  if (guardado == true && context.mounted) refrescarAvisos(ref);
}

/// Marca cumplido. Pregunta antes porque **no se puede desmarcar**, y el botón
/// es grande y está siempre a mano: un roce al bajar por la lista no puede
/// dar por hecho un mantenimiento.
Future<void> cumplirAviso(
  BuildContext context,
  WidgetRef ref,
  Recordatorio r, {
  bool preguntar = true,
}) async {
  if (preguntar) {
    final seguro = await confirmar(
      context,
      titulo: '¿Marcar como cumplido?',
      mensaje: '${tituloDe(r)}\n\nDespués no se puede desmarcar.',
    );
    if (!seguro || !context.mounted) return;
  }

  final siguiente = await ref
      .read(recordatoriosRepoProvider)
      .marcarCumplido(r.id!);
  if (!context.mounted) return;

  mostrarAviso(
    context,
    siguiente == null
        ? 'Listo, marcado como cumplido.'
        : 'Cumplido. El próximo queda para '
              '${diaMes(r.repite!.siguiente(r.fecha))}.',
  );
  refrescarAvisos(ref);
}

/// Saca un aviso de la lista. Queda en el historial, en gris.
Future<void> eliminarAviso(
  BuildContext context,
  WidgetRef ref,
  Recordatorio r,
) async {
  final repo = ref.read(recordatoriosRepoProvider);

  if (!r.seRepite) {
    final seguro = await confirmar(
      context,
      titulo: '¿Eliminar este aviso?',
      mensaje: 'Se queda en el historial como Eliminado.',
      destructivo: true,
    );
    if (!seguro || !context.mounted) return;

    await repo.eliminar(r.id!);
  } else {
    final opcion = await showDialog<_FormaDeEliminar>(
      context: context,
      builder: (_) => const _VentanaEliminarRepetido(),
    );
    if (opcion == null || !context.mounted) return;

    switch (opcion) {
      case _FormaDeEliminar.dejarDeRepetir:
        await repo.dejarDeRepetir(r.id!);
      case _FormaDeEliminar.soloEste:
        await repo.eliminarYSeguir(r.id!);
      case _FormaDeEliminar.esteYDejarDeRepetir:
        await repo.eliminar(r.id!);
    }
  }

  if (context.mounted) refrescarAvisos(ref);
}

/// Borra un eliminado de verdad. Lo único de esta pantalla sin vuelta atrás
/// que además hace desaparecer el dato.
Future<bool> borrarParaSiempre(
  BuildContext context,
  WidgetRef ref,
  Recordatorio r,
) async {
  final seguro = await confirmar(
    context,
    titulo: '¿Borrar para siempre?',
    mensaje: '${tituloDe(r)}\n\nYa no va a aparecer en el historial.',
    destructivo: true,
  );
  if (!seguro || !context.mounted) return false;

  await ref.read(recordatoriosRepoProvider).borrarParaSiempre(r.id!);
  if (context.mounted) refrescarAvisos(ref);
  return true;
}

enum _AccionDetalle { cumplir, editar, importante, eliminar }

/// La ventana que se abre al tocar una tarjeta.
Future<void> abrirAviso(
  BuildContext context,
  WidgetRef ref,
  Recordatorio r,
) async {
  final accion = await mostrarHoja<_AccionDetalle>(
    context,
    titulo: tituloDe(r),
    bajada: clienteEquipoDe(r),
    contenido: (hoja) => _DetalleAviso(recordatorio: r),
  );
  if (accion == null || !context.mounted) return;

  switch (accion) {
    case _AccionDetalle.cumplir:
      // Ya abrió la tarjeta y eligió Cumplido: preguntar otra vez sobra.
      await cumplirAviso(context, ref, r, preguntar: false);
    case _AccionDetalle.editar:
      await _abrirFormulario(context, ref, r);
    case _AccionDetalle.importante:
      await ref
          .read(recordatoriosRepoProvider)
          .marcarImportante(r.id!, !r.importante);
      if (context.mounted) refrescarAvisos(ref);
    case _AccionDetalle.eliminar:
      await eliminarAviso(context, ref, r);
  }
}

class _DetalleAviso extends StatelessWidget {
  const _DetalleAviso({required this.recordatorio});

  final Recordatorio recordatorio;

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;
    void elegir(_AccionDetalle a) => Navigator.of(context).pop(a);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.xl, 0, Espacio.xl, Espacio.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Espacio.sm,
            runSpacing: Espacio.xs,
            children: [
              ChipFecha(fecha: r.fecha),
              if (r.seRepite) ChipRepite(texto: r.repite!.etiqueta),
            ],
          ),
          const SizedBox(height: Espacio.xl),
          FilledButton.icon(
            onPressed: () => elegir(_AccionDetalle.cumplir),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Cumplido'),
          ),
          const SizedBox(height: Espacio.md),
          OutlinedButton.icon(
            onPressed: () => elegir(_AccionDetalle.editar),
            icon: const Icon(Icons.edit_rounded, size: 19),
            label: const Text('Editar'),
          ),
          const SizedBox(height: Espacio.sm),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => elegir(_AccionDetalle.importante),
                  icon: Icon(
                    r.importante
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: Tono.oro,
                  ),
                  label: const Text('Importante'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => elegir(_AccionDetalle.eliminar),
                  style: TextButton.styleFrom(foregroundColor: Tono.vino),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _FormaDeEliminar { dejarDeRepetir, soloEste, esteYDejarDeRepetir }

/// Un aviso que se repite no se elimina de una sola forma: puede querer
/// saltearse esta vez, o que no vuelva nunca más. Se pregunta en una sola
/// ventana, con las tres salidas a la vista.
class _VentanaEliminarRepetido extends StatefulWidget {
  const _VentanaEliminarRepetido();

  @override
  State<_VentanaEliminarRepetido> createState() =>
      _VentanaEliminarRepetidoState();
}

class _VentanaEliminarRepetidoState extends State<_VentanaEliminarRepetido> {
  _FormaDeEliminar? _elegida;

  Widget _opcion(_FormaDeEliminar valor, String titulo, String detalle) {
    final activa = _elegida == valor;

    return InkWell(
      onTap: () => setState(() => _elegida = valor),
      borderRadius: Redondeo.brChico,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacio.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              activa
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: activa ? Tono.vino : Tono.texto3,
            ),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Tipo.encabezado),
                  const SizedBox(height: 2),
                  Text(detalle, style: Tipo.secundario),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elegida = _elegida;
    final borra = elegida != null && elegida != _FormaDeEliminar.dejarDeRepetir;

    return AlertDialog(
      title: const Text('Este aviso se repite'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcion(
              _FormaDeEliminar.dejarDeRepetir,
              'Dejar de repetir',
              'Este sigue en la lista, pero ya no se programa otro.',
            ),
            _opcion(
              _FormaDeEliminar.soloEste,
              'Eliminar solo este',
              'El siguiente se programa igual.',
            ),
            _opcion(
              _FormaDeEliminar.esteYDejarDeRepetir,
              'Eliminar este y dejar de repetir',
              'No se programa otro.',
            ),
          ],
        ),
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
          // Rojo solo si borra: dejar de repetir no saca nada de la lista.
          style: FilledButton.styleFrom(
            backgroundColor: borra ? Tono.vino : Tono.negro,
          ),
          onPressed: elegida == null
              ? null
              : () => Navigator.of(context).pop(elegida),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
