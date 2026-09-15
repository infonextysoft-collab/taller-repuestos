import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/repositories/auth_repository.dart';

/// Qué se eligió en el menú del negocio.
enum AccionNegocio { datos, respaldo, correo, clave, salir }

/// La barra de arriba.
///
/// El **menú va a la izquierda** y la identidad del negocio a la derecha, al
/// revés de lo habitual, y es a propósito: el logo y el RUC son un dato fijo
/// que ya se sabe, mientras que el menú es lo único que se toca. Lo que se
/// toca va donde llega el pulgar; lo que solo se lee, del otro lado.
class BarraSuperior extends ConsumerWidget implements PreferredSizeWidget {
  const BarraSuperior({super.key, required this.onAccion});

  final ValueChanged<AccionNegocio> onAccion;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocio = ref.watch(negocioProvider);
    final nombre = negocio.nombre.trim();
    final sinConfigurar = nombre.isEmpty;
    final cuenta = ref.watch(estadoCuentaProvider).valueOrNull;

    return Material(
      color: Tono.fondo,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(Espacio.sm, 0, Espacio.lg, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Tono.linea)),
          ),
          child: Row(
            children: [
              _MenuNegocio(
                onAccion: onAccion,
                avisar: sinConfigurar,
                cuenta: cuenta,
              ),
              const Spacer(),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sinConfigurar ? 'MS' : nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipo.encabezado.copyWith(fontSize: 17),
                    ),
                    Text(
                      sinConfigurar
                          ? 'Completa los datos del negocio'
                          : (negocio.ruc.trim().isEmpty
                              ? 'Sin RUC'
                              : 'RUC ${negocio.ruc}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipo.nota.copyWith(
                        color: sinConfigurar ? Tono.vinoTexto : Tono.texto3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espacio.md),
              Image.asset(
                'assets/img/logo.png',
                width: 34,
                height: 34,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.bolt_rounded,
                  color: Tono.vino,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El desplegable del negocio.
///
/// Se descuelga del propio botón —arranca donde se tocó— en vez de aparecer
/// como una ventanita suelta en el medio de la pantalla. Y va sobre superficie
/// oscura, igual que la barra de abajo y el marcador: es la misma capa de la
/// app, así que se ve igual.
class _MenuNegocio extends StatelessWidget {
  const _MenuNegocio({
    required this.onAccion,
    required this.avisar,
    required this.cuenta,
  });

  final ValueChanged<AccionNegocio> onAccion;

  /// Un punto sobre el botón mientras falten los datos del emisor: sin ellos
  /// los documentos salen sin cabecera, y eso no se descubre hasta imprimir.
  final bool avisar;

  /// Para la recuperación por correo. Sin cuenta disponible —la vista web, un
  /// build sin Firebase— la opción no aparece: no habría nada que hacer ahí.
  final EstadoCuenta? cuenta;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AccionNegocio>(
        onSelected: onAccion,
        tooltip: 'Negocio',
        offset: const Offset(0, 8),
        color: Tono.negro,
        elevation: 12,
        menuPadding: const EdgeInsets.symmetric(vertical: Espacio.sm),
        shape: const RoundedRectangleBorder(borderRadius: Redondeo.brNormal),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          _item(AccionNegocio.datos, Icons.storefront_rounded,
              'Datos del negocio', 'Lo que sale impreso en el documento'),
          _item(AccionNegocio.respaldo, Icons.save_alt_rounded, 'Respaldo',
              'Guardar todo por si pierdes el teléfono'),
          // Con correo vinculado se muestra aunque no haya Firebase: es el único
          // lugar desde donde se desvincula, y desvincular no necesita red.
          if ((cuenta?.nubeDisponible ?? false) || (cuenta?.conCorreo ?? false))
            _item(
              AccionNegocio.correo,
              Icons.mail_outline_rounded,
              'Recuperación por correo',
              // Completo, no tapado: acá ya se entró, y un error de tipeo solo
              // se ve leyéndolo entero.
              cuenta!.correo == null
                  ? 'Por si olvidas la contraseña'
                  : cuenta!.correo!,
            ),
          _item(AccionNegocio.clave, Icons.lock_outline_rounded,
              'Cambiar contraseña', null),
          const PopupMenuDivider(color: Tono.negroLinea, height: Espacio.md),
          _item(AccionNegocio.salir, Icons.logout_rounded, 'Cerrar sesión',
              null),
        ],
        child: Container(
          width: kAreaTactil,
          height: kAreaTactil,
          margin: const EdgeInsets.only(left: Espacio.sm),
          decoration: BoxDecoration(
            color: Tono.fondo2,
            borderRadius: Redondeo.brChico,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.storefront_rounded,
                  size: 21, color: Tono.texto2),
              if (avisar)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Tono.vino,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  PopupMenuItem<AccionNegocio> _item(
    AccionNegocio valor,
    IconData icono,
    String texto,
    String? detalle,
  ) =>
      PopupMenuItem<AccionNegocio>(
        value: valor,
        height: detalle == null ? 46 : 56,
        child: Row(
          children: [
            Icon(icono, size: 19, color: Tono.oroClaro),
            const SizedBox(width: Espacio.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    texto,
                    style: Tipo.encabezado.copyWith(
                      fontSize: 15,
                      color: Tono.textoInverso,
                    ),
                  ),
                  if (detalle != null)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipo.nota.copyWith(color: Tono.textoInverso2),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
