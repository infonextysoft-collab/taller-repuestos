import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/avisos.dart';
import '../../../core/widgets/hoja.dart';
import '../../../domain/entities/trabajo.dart';
import '../historial/pantalla_historial.dart';
import '../inventario/pantalla_inventario.dart';
import '../negocio/formulario_clave.dart';
import '../negocio/pantalla_negocio.dart';
import '../negocio/pantalla_respaldo.dart';
import '../negocio/ventana_correo.dart';
import '../recordatorios/pantalla_recordatorios.dart';
import '../reportes/pantalla_reportes.dart';
import '../trabajo/wizard_trabajo.dart';
import '../venta/pantalla_venta_simple.dart';
import 'barra_inferior.dart';
import 'barra_superior.dart';

/// El armazón: barra de arriba, tres secciones y el botón "+".
///
/// Ya no sale un aviso emergente de vencidos al abrir: la primera tarjeta del
/// Historial dice lo mismo, con el nombre del cliente y sin desaparecer a los
/// cinco segundos.
class ShellPrincipal extends ConsumerStatefulWidget {
  const ShellPrincipal({super.key, required this.alSalir});

  final Future<void> Function() alSalir;

  @override
  ConsumerState<ShellPrincipal> createState() => _ShellPrincipalState();
}

class _ShellPrincipalState extends ConsumerState<ShellPrincipal> {
  int _seccion = 0;

  /* ------------------------------------------------------- nuevo registro */

  /// Dos opciones, no tres.
  ///
  /// Taller y campo eran el mismo formulario con el mismo wizard: la única
  /// diferencia real es dónde se hizo, y eso ya se pregunta adentro, en el
  /// paso del lugar. Preguntarlo dos veces era hacer elegir antes de tener
  /// con qué decidir.
  Future<void> _nuevoRegistro() async {
    final tipo = await mostrarHoja<TipoTrabajo>(
      context,
      titulo: 'Nuevo registro',
      bajada: '¿Qué vas a cargar?',
      contenido: (hoja) => Padding(
        padding: const EdgeInsets.only(bottom: Espacio.lg),
        child: Column(
          children: [
            OpcionHoja(
              icono: Icons.handyman_rounded,
              titulo: 'Trabajo',
              detalle: 'Reparación o servicio, en el taller o en campo.',
              destacada: true,
              onTap: () => Navigator.of(hoja).pop(TipoTrabajo.taller),
            ),
            OpcionHoja(
              icono: Icons.sell_rounded,
              titulo: 'Venta de repuestos',
              detalle: 'Solo piezas, sin trabajo de por medio.',
              color: Tono.oro,
              onTap: () => Navigator.of(hoja).pop(TipoTrabajo.venta),
            ),
          ],
        ),
      ),
    );

    if (tipo == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => tipo == TipoTrabajo.venta
            ? const PantallaVentaSimple()
            : const WizardTrabajo(),
      ),
    );

    if (!mounted) return;
    _refrescarTodo();
    setState(() => _seccion = 0);
  }

  void _refrescarTodo() {
    ref.read(refrescoHistorialProvider.notifier).state++;
    ref.read(refrescoInventarioProvider.notifier).state++;
    ref.read(refrescoRecordatoriosProvider.notifier).state++;
    ref.invalidate(vencidosProvider);
  }

  /* --------------------------------------------------------- menú negocio */

  Future<void> _accionNegocio(AccionNegocio accion) async {
    switch (accion) {
      case AccionNegocio.datos:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PantallaNegocio()),
        );

      case AccionNegocio.reportes:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PantallaReportes()),
        );

      case AccionNegocio.respaldo:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PantallaRespaldo()),
        );

      case AccionNegocio.correo:
        final cambiarClave = await mostrarHoja<bool>(
          context,
          titulo: 'Recuperación por correo',
          bajada: 'Si olvidas la contraseña, te mandamos un enlace a tu correo.',
          contenido: (hoja) => VentanaCorreo(
            onListo: () => Navigator.of(hoja).pop(),
            onCambiarClave: () => Navigator.of(hoja).pop(true),
          ),
        );
        // Se invalida al cerrar y no desde adentro: así la ventana no cambia
        // de cara mientras se va. Si el armazón ya no está —la sesión venció
        // con la ventana abierta—, la ventana lo avisó sola.
        if (!mounted) return;
        ref.invalidate(estadoCuentaProvider);
        if (cambiarClave == true) {
          await _accionNegocio(AccionNegocio.clave);
        }

      case AccionNegocio.clave:
        final conCorreo =
            ref.read(estadoCuentaProvider).valueOrNull?.conCorreo ?? false;
        await mostrarHoja<void>(
          context,
          titulo: 'Cambiar contraseña',
          bajada: conCorreo
              ? 'Es la de tu cuenta de correo: hace falta la actual y '
                  'conexión a internet.'
              : 'Hace falta la actual para poder cambiarla.',
          contenido: (hoja) =>
              FormularioClave(onListo: () => Navigator.of(hoja).pop()),
        );
        if (mounted) ref.invalidate(estadoCuentaProvider);

      case AccionNegocio.salir:
        final seguro = await confirmar(
          context,
          titulo: '¿Cerrar sesión?',
          mensaje: 'Los datos quedan en el dispositivo. Solo te vuelve a '
              'pedir la contraseña.',
          aceptar: 'Cerrar sesión',
          cancelar: 'Permanecer',
          destructivo: true,
        );
        if (seguro) await widget.alSalir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vencidos = ref.watch(vencidosProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Tono.fondo2,
      appBar: BarraSuperior(onAccion: _accionNegocio),
      // La barra va en un Stack y no en `bottomNavigationBar` porque flota:
      // el contenido tiene que seguir viéndose por debajo del vidrio, que es
      // lo que dice que la lista continúa. Cada pantalla reserva `kAltoBarra`
      // al final de su scroll para que la última fila quede alcanzable.
      body: Stack(
        children: [
          // IndexedStack y no un switch: cambiar de sección no puede perder el
          // scroll ni los filtros que la persona ya dejó puestos.
          IndexedStack(
            index: _seccion,
            children: [
              PantallaHistorial(
                onSeccion: (i) => setState(() => _seccion = i),
              ),
              const PantallaInventario(),
              const PantallaRecordatorios(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BarraInferior(
              seccion: _seccion,
              vencidos: vencidos,
              onSeccion: (i) => setState(() => _seccion = i),
              onNuevo: _nuevoRegistro,
            ),
          ),
        ],
      ),
    );
  }
}
