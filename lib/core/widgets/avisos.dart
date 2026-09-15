import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Aviso corto abajo. Para lo que el usuario tiene que enterarse pero no
/// decidir —"se dividió la línea", "se guardó"—.
void mostrarAviso(
  BuildContext context,
  String mensaje, {
  bool problema = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              problema
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: Espacio.md),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: problema ? Tono.vino : Tono.texto,
        duration: Duration(seconds: problema ? 5 : 3),
        // El margen de abajo despeja lo que flota ahí: la barra de navegación
        // en las pantallas del armazón, y la barra de acción en los
        // formularios. Sin esto el aviso tapa justo el botón que se acaba de
        // tocar.
        margin: const EdgeInsets.fromLTRB(Espacio.lg, 0, Espacio.lg, 98),
      ),
    );
}

/// Confirmación de dos salidas. Devuelve `true` si el usuario eligió la
/// acción principal.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String aceptar = 'Continuar',
  String cancelar = 'Permanecer',
  bool destructivo = false,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actionsPadding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        0,
        Espacio.lg,
        Espacio.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelar),
        ),
        FilledButton(
          style: destructivo
              ? FilledButton.styleFrom(backgroundColor: Tono.vino)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(aceptar),
        ),
      ],
    ),
  );

  return respuesta ?? false;
}

/// Qué se eligió al intentar salir de un registro a medias.
enum SalidaWizard { permanecer, guardar }

/// Salir del wizard: **dos** salidas, no tres.
///
/// "Descartar" sobraba. Lo que se escribió ya está guardado en la base desde
/// el primer paso, así que descartar no borraba nada real: solo agregaba una
/// tercera opción que obligaba a leer las tres para elegir. O seguís, o
/// guardás y volvés después.
Future<SalidaWizard> confirmarSalida(BuildContext context) async {
  final respuesta = await showDialog<SalidaWizard>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Salir del registro?'),
      content: const Text(
        'Queda como pendiente en el historial y puedes seguir donde lo '
        'dejaste.',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Espacio.lg,
        0,
        Espacio.lg,
        Espacio.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(SalidaWizard.permanecer),
          child: const Text('Permanecer'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(SalidaWizard.guardar),
          child: const Text('Guardar y salir'),
        ),
      ],
    ),
  );

  return respuesta ?? SalidaWizard.permanecer;
}

/// Un aviso que hay que leer con calma: queda en pantalla hasta que se cierra.
///
/// Para lo que trae una instrucción —"revisa tu correo, y si no llega…"—. El
/// aviso de abajo se va a los pocos segundos y eso no alcanza para leerlo.
Future<void> informar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String boton = 'Entendido',
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actionsPadding: const EdgeInsets.fromLTRB(
          Espacio.lg,
          0,
          Espacio.lg,
          Espacio.lg,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(boton),
          ),
        ],
      ),
    );
