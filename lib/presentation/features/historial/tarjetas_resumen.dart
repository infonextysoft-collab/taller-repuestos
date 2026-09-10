import 'package:flutter/material.dart';

import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/textura.dart';
import '../../../domain/entities/resumen_taller.dart';

/// Las tarjetas de arriba del Historial: lo que hay que atender, deslizable.
///
/// Reemplazan al marcador de plata. En una app para un técnico solo, "cuánto
/// registré desde siempre" es un número que solo crece y no contesta nada; lo
/// que sí se pregunta al abrir es **a quién le toca, qué quedó a medias y qué
/// repuesto falta**.
///
/// Dos reglas que las hacen útiles:
///
///   - **Se ordenan solas por urgencia** y las vacías no se muestran. Así la
///     primera tarjeta nunca es un cero, y si no hay nada queda una sola que lo
///     dice.
///   - **Cuando hay uno solo, el nombre es el titular.** "1 vence hoy" te
///     obliga a entrar a averiguar a quién llamar; "Juan Ramírez" ya te lo
///     dice. Recién con dos o más manda la cuenta.
class TarjetasResumen extends StatefulWidget {
  const TarjetasResumen({
    super.key,
    required this.resumen,
    required this.onAvisos,
    required this.onSinCerrar,
    required this.onInventario,
  });

  final ResumenTaller resumen;

  /// Ir a la pestaña de Avisos.
  final VoidCallback onAvisos;

  /// Filtrar el historial por los que están sin cerrar.
  final VoidCallback onSinCerrar;

  /// Ir al inventario, mostrando lo agotado.
  final VoidCallback onInventario;

  @override
  State<TarjetasResumen> createState() => _TarjetasResumenState();
}

class _TarjetasResumenState extends State<TarjetasResumen> {
  final _paginas = PageController();
  int _actual = 0;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  List<_Contenido> get _tarjetas {
    final r = widget.resumen;
    final lista = <_Contenido>[];

    if (r.pendientesHoy.isNotEmpty) {
      final primero = r.pendientesHoy.first;
      final quien = (primero.cliente ?? '').trim();

      lista.add(_Contenido(
        rotulo: 'Hoy toca',
        icono: Icons.event_available_rounded,
        titulo: quien.isEmpty ? primero.descripcion.trim() : quien,
        detalle: [
          if (quien.isNotEmpty) primero.descripcion.trim(),
          if ((primero.equipo ?? '').trim().isNotEmpty) primero.equipo!.trim(),
        ].where((t) => t.isNotEmpty).join(' · '),
        extra: r.pendientesHoy.length > 1
            ? '+ ${r.pendientesHoy.length - 1} más'
            : null,
        onTap: widget.onAvisos,
      ));
    }

    if (r.sinCerrar.isNotEmpty) {
      lista.add(_Contenido(
        rotulo: 'Sin cerrar',
        icono: Icons.pending_actions_rounded,
        titulo: r.sinCerrar.length == 1
            ? _nombre(r.sinCerrar.first.cliente)
            : '${r.sinCerrar.length} registros',
        detalle: r.sinCerrar.length == 1
            ? 'Desde el ${formatoCorto(r.sinCerrar.first.fecha)}'
            : r.sinCerrar.take(3).map((t) => _nombre(t.cliente)).join(' · '),
        extra: r.sinCerrar.length > 3 ? '+ ${r.sinCerrar.length - 3} más' : null,
        onTap: widget.onSinCerrar,
      ));
    }

    if (r.sinStock.isNotEmpty) {
      lista.add(_Contenido(
        rotulo: 'Sin stock',
        icono: Icons.inventory_2_rounded,
        titulo: r.sinStock.length == 1
            ? r.sinStock.first.nombre
            : '${r.sinStock.length} repuestos',
        detalle: r.sinStock.length == 1
            ? 'Se acabó'
            : r.sinStock.take(3).map((p) => p.nombre).join(' · '),
        extra: r.sinStock.length > 3 ? '+ ${r.sinStock.length - 3} más' : null,
        onTap: widget.onInventario,
      ));
    }

    if (lista.isEmpty) {
      lista.add(_Contenido(
        rotulo: 'Al día',
        icono: Icons.check_circle_outline_rounded,
        titulo: 'Nada pendiente',
        detalle: r.proximoMantenimiento == null
            ? 'No hay mantenimientos agendados.'
            : 'El próximo mantenimiento es el '
                '${formatoLargo(r.proximoMantenimiento!)}.',
        onTap: widget.onAvisos,
      ));
    }

    return lista;
  }

  static String _nombre(String cliente) =>
      cliente.trim().isEmpty ? 'Sin cliente' : cliente.trim();

  @override
  Widget build(BuildContext context) {
    final tarjetas = _tarjetas;
    // Si desaparece la tarjeta que se estaba viendo, no puede quedar la página
    // apuntando a un índice que ya no existe.
    final indice = _actual.clamp(0, tarjetas.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _paginas,
            itemCount: tarjetas.length,
            onPageChanged: (i) => setState(() => _actual = i),
            itemBuilder: (_, i) => _Tarjeta(contenido: tarjetas[i]),
          ),
        ),
        if (tarjetas.length > 1) ...[
          const SizedBox(height: Espacio.md),
          _Puntos(cantidad: tarjetas.length, actual: indice),
        ],
      ],
    );
  }
}

/// Lo que muestra una tarjeta. Es un dato, no un widget: así el orden y qué
/// tarjetas existen se decide en un solo lugar.
class _Contenido {
  const _Contenido({
    required this.rotulo,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.extra,
  });

  final String rotulo;
  final IconData icono;
  final String titulo;
  final String detalle;
  final String? extra;
  final VoidCallback onTap;
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.contenido});

  final _Contenido contenido;

  @override
  Widget build(BuildContext context) {
    final c = contenido;

    return ClipRRect(
      borderRadius: Redondeo.brNormal,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Tono.vino, Tono.vinoNoche],
              stops: [0, 0.88],
            ),
          ),
          child: InkWell(
            onTap: c.onTap,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: EstriasDiagonales()),
                ),
                Padding(
                  padding: const EdgeInsets.all(Espacio.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // El "+N más" y la flecha van arriba, en la línea del
                      // rótulo. Abajo le robaban el ancho al detalle, que es
                      // donde dice de qué equipo se trata.
                      Row(
                        children: [
                          Expanded(
                            child: _Rotulo(texto: c.rotulo, icono: c.icono),
                          ),
                          if (c.extra != null) ...[
                            Text(
                              c.extra!,
                              style: Tipo.nota.copyWith(color: Tono.oroClaro),
                            ),
                            const SizedBox(width: Espacio.md),
                          ],
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                            color: Tono.oroClaro,
                          ),
                        ],
                      ),
                      const SizedBox(height: Espacio.md),
                      Text(
                        c.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tipo.display.copyWith(
                          fontSize: 30,
                          color: Tono.textoInverso,
                        ),
                      ),
                      const SizedBox(height: Espacio.sm),
                      Text(
                        c.detalle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Tipo.secundario.copyWith(color: Tono.textoInverso2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El rótulo, con la marca de oro inclinada adelante. Misma inclinación que
/// las estrías del fondo y que el subrayado de la barra de abajo.
class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Transform(
            transform: Matrix4.skewX(-0.32),
            child: Container(width: 4, height: 15, color: Tono.oroVivo),
          ),
          const SizedBox(width: Espacio.md),
          Icon(icono, size: 15, color: Tono.oroClaro),
          const SizedBox(width: Espacio.sm),
          Flexible(
            child: Text(
              texto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tipo.etiqueta.copyWith(color: Tono.oroClaro),
            ),
          ),
        ],
      );
}

class _Puntos extends StatelessWidget {
  const _Puntos({required this.cantidad, required this.actual});

  final int cantidad;
  final int actual;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < cantidad; i++)
            AnimatedContainer(
              duration: duracion(context, Movimiento.micro),
              curve: Movimiento.salida,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              // El activo se alarga en vez de cambiar de color: sobre el fondo
              // hueso, dos grises parecidos no se distinguen de reojo.
              width: i == actual ? 18 : 5,
              decoration: BoxDecoration(
                color: i == actual ? Tono.vino : Tono.lineaFuerte,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      );
}
