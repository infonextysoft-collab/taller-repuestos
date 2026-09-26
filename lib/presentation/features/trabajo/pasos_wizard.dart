import 'package:flutter/material.dart';

import '../../../core/theme/movimiento.dart';
import '../../../core/theme/tipografia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dinero.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/utils/validacion.dart';
import '../../../core/widgets/campo.dart';
import '../../../core/widgets/campo_documento.dart';
import '../../../core/widgets/contenido.dart';
import '../../../core/widgets/pulsable.dart';
import '../../../core/widgets/resumen_totales.dart';
import '../../../core/widgets/tabla_items.dart';
import '../../../domain/entities/foto.dart';
import '../../../domain/entities/repeticion.dart';
import '../../../domain/entities/trabajo.dart';
import '../../comunes/agregar_mano_obra.dart';
import '../../comunes/campo_fecha.dart';
import '../../comunes/controlador_registro.dart';
import '../../comunes/galeria_fotos.dart';
import '../../comunes/selector_repeticion.dart';
import '../../comunes/selector_repuesto.dart';

/// Los controladores de texto del wizard, en un solo lugar.
///
/// Van juntos porque los pasos se montan y desmontan al navegar: si cada paso
/// creara los suyos, volver atrás perdería lo escrito o duplicaría estado.
class CamposWizard {
  final cliente = TextEditingController();
  final ruc = TextEditingController();
  final facturarA = TextEditingController();
  final equipo = TextEditingController();
  final modelo = TextEditingController();
  final placa = TextEditingController();
  final anio = TextEditingController();
  final nMotor = TextEditingController();
  final vin = TextEditingController();
  final ubicacion = TextEditingController();
  final vueltas = TextEditingController(text: '1');
  final precioVuelta = TextEditingController();
  final observaciones = TextEditingController();
  final diagnostico = TextEditingController();
  final recomendaciones = TextEditingController();
  final descuento = TextEditingController();

  void sembrar(Trabajo t) {
    cliente.text = t.cliente;
    ruc.text = t.ruc;
    facturarA.text = t.facturarA;
    equipo.text = t.equipo;
    modelo.text = t.modelo;
    placa.text = t.placa;
    anio.text = t.anio;
    nMotor.text = t.nMotor;
    vin.text = t.vin;
    ubicacion.text = t.ubicacion;
    if (t.vueltas > 0) vueltas.text = '${t.vueltas}';
    if (t.precioVuelta > 0) {
      precioVuelta.text = t.precioVuelta.toStringAsFixed(2);
    }
    observaciones.text = t.observaciones;
    diagnostico.text = t.diagnostico;
    recomendaciones.text = t.recomendaciones;
    if (t.descuento > 0) descuento.text = t.descuento.toStringAsFixed(2);
  }

  void dispose() {
    for (final c in [
      cliente,
      ruc,
      facturarA,
      equipo,
      modelo,
      placa,
      anio,
      nMotor,
      vin,
      ubicacion,
      vueltas,
      precioVuelta,
      observaciones,
      diagnostico,
      recomendaciones,
      descuento,
    ]) {
      c.dispose();
    }
  }
}

/// El cuerpo del paso que toque. Cada paso es una sección chica y
/// autocontenida, con su propio encabezado: saber qué se está haciendo no
/// puede depender de recordar el número del paso.
class PasoWizard extends StatelessWidget {
  const PasoWizard({
    super.key,
    required this.paso,
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
    required this.onAviso,
  });

  final int paso;
  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;
  final ValueChanged<String> onAviso;

  @override
  Widget build(BuildContext context) => switch (paso) {
        1 => _ClienteEquipo(ctrl: ctrl, campos: campos, bloqueado: bloqueado),

        // Las dos tandas de fotos son **una** pantalla. Es la misma acción con
        // el celular en la mano, y separarlas dejaba dos pasos con dos botones
        // cada uno y el resto en blanco.
        2 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Fotos(
                titulo: 'Cómo llegó el equipo',
                detalle: 'Tómalas ahora, mientras lo tienes delante.',
                fotos: ctrl.registro.fotosIngreso,
                bloqueado: bloqueado,
                onCambio: (f) =>
                    ctrl.editar((t) => t.copyWith(fotosIngreso: f)),
              ),
              _Fotos(
                titulo: 'Cómo quedó',
                detalle: 'Es lo que respalda el trabajo si hay un reclamo.',
                secundario: true,
                fotos: ctrl.registro.fotosEntrega,
                bloqueado: bloqueado,
                onCambio: (f) =>
                    ctrl.editar((t) => t.copyWith(fotosEntrega: f)),
              ),
            ],
          ),

        // Dónde fue y qué encontraste: lo que pasó con el equipo, junto.
        3 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Lugar(ctrl: ctrl, campos: campos, bloqueado: bloqueado),
              _Diagnostico(
                ctrl: ctrl,
                campos: campos,
                bloqueado: bloqueado,
                secundario: true,
              ),
            ],
          ),

        // Mano de obra y repuestos contestan la misma pregunta —qué se cobra—
        // y hasta ahora obligaban a cambiar de pantalla en el medio de armar
        // el precio.
        4 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ManoDeObra(ctrl: ctrl, bloqueado: bloqueado),
              _Repuestos(
                ctrl: ctrl,
                bloqueado: bloqueado,
                onAviso: onAviso,
                secundario: true,
              ),
            ],
          ),

        5 => _Recomendaciones(ctrl: ctrl, campos: campos, bloqueado: bloqueado),
        _ => _Totales(ctrl: ctrl, campos: campos, bloqueado: bloqueado),
      };
}

/// Encabezado de paso: qué se está haciendo y por qué, en una línea.
///
/// En [secundario] baja de nivel y se separa con una línea: es lo que permite
/// que dos temas convivan en un paso sin que parezcan el mismo. La jerarquía
/// la da el tamaño y el aire, no otro color.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.titulo,
    this.detalle,
    this.secundario = false,
  });

  final String titulo;
  final String? detalle;
  final bool secundario;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          top: secundario ? Espacio.xxl : 0,
          bottom: Espacio.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (secundario) ...[
              const Divider(height: 1),
              const SizedBox(height: Espacio.xl),
            ],
            Text(titulo, style: secundario ? Tipo.titulo2 : Tipo.titulo1),
            if (detalle != null) ...[
              const SizedBox(height: Espacio.sm),
              Text(detalle!, style: Tipo.secundario),
            ],
          ],
        ),
      );
}

/* ------------------------------------------------------------------ paso 1 */

class _ClienteEquipo extends StatelessWidget {
  const _ClienteEquipo({
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
  });

  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final t = ctrl.registro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          titulo: '¿Para quién es el trabajo?',
          detalle: 'Estos datos van impresos en el reporte y en la boleta.',
        ),
        Campo(
          etiqueta: 'Cliente',
          controlador: campos.cliente,
          ejemplo: 'Para quién es el trabajo',
          habilitado: !bloqueado,
          autofoco: !bloqueado && t.cliente.isEmpty,
          textoAccion: TextInputAction.next,
          validador: Valida.todos([
            Valida.obligatorio('el nombre del cliente'),
            Valida.minimo(2, 'El nombre'),
          ]),
          onCambio: (v) => ctrl.editar((r) => r.copyWith(cliente: v)),
        ),
        const SizedBox(height: Espacio.lg),
        CampoDocumento(
          controlador: campos.ruc,
          habilitado: !bloqueado,
          onCambio: (v) => ctrl.editar((r) => r.copyWith(ruc: v)),
        ),
        const SizedBox(height: Espacio.lg),
        Campo(
          etiqueta: 'Facturar a',
          controlador: campos.facturarA,
          ejemplo: 'Si va a otro nombre',
          opcional: true,
          ayuda: 'Vacío usa el nombre del cliente.',
          habilitado: !bloqueado,
          onCambio: (v) => ctrl.editar((r) => r.copyWith(facturarA: v)),
        ),
        // Sin encabezado "Equipo": abajo va un campo que ya se llama "Qué
        // equipo es". Dos etiquetas en mayúscula, una encima de la otra,
        // diciendo lo mismo, es ruido con forma de jerarquía.
        const SizedBox(height: Espacio.xxl),
        Seccion(
          child: Column(
            children: [
              Campo(
                etiqueta: 'Qué equipo es',
                controlador: campos.equipo,
                ejemplo: 'Ej. Motor trifásico 5 HP',
                habilitado: !bloqueado,
                textoAccion: TextInputAction.next,
                validador: Valida.obligatorio('el equipo'),
                onCambio: (v) => ctrl.editar((r) => r.copyWith(equipo: v)),
              ),
              const SizedBox(height: Espacio.lg),
              Campo(
                etiqueta: 'Modelo o N° de serie',
                controlador: campos.modelo,
                ejemplo: 'Lo que diga la chapa',
                opcional: true,
                habilitado: !bloqueado,
                textoAccion: TextInputAction.next,
                onCambio: (v) => ctrl.editar((r) => r.copyWith(modelo: v)),
              ),
              const SizedBox(height: Espacio.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Campo(
                      etiqueta: 'Placa',
                      controlador: campos.placa,
                      ejemplo: 'T7D164',
                      habilitado: !bloqueado,
                      textoAccion: TextInputAction.next,
                      validador: Valida.obligatorio('la placa'),
                      onCambio: (v) =>
                          ctrl.editar((r) => r.copyWith(placa: v)),
                    ),
                  ),
                  const SizedBox(width: Espacio.md),
                  Expanded(
                    child: Campo(
                      etiqueta: 'Año',
                      controlador: campos.anio,
                      ejemplo: '2023',
                      opcional: true,
                      teclado: TextInputType.number,
                      habilitado: !bloqueado,
                      textoAccion: TextInputAction.next,
                      onCambio: (v) => ctrl.editar((r) => r.copyWith(anio: v)),
                    ),
                  ),
                ],
              ),
              // Los dos de abajo son largos y van solos: partidos en dos
              // columnas se leen a medias y se tipean peor.
              const SizedBox(height: Espacio.lg),
              Campo(
                etiqueta: 'N° de motor',
                controlador: campos.nMotor,
                ejemplo: '15S4C9KGN6280408',
                opcional: true,
                habilitado: !bloqueado,
                textoAccion: TextInputAction.next,
                onCambio: (v) => ctrl.editar((r) => r.copyWith(nMotor: v)),
              ),
              const SizedBox(height: Espacio.lg),
              Campo(
                etiqueta: 'VIN',
                controlador: campos.vin,
                ejemplo: 'LSJA36E31PZ042103',
                opcional: true,
                ayuda: 'Los tres opcionales salen impresos solo si los '
                    'cargas.',
                habilitado: !bloqueado,
                onCambio: (v) => ctrl.editar((r) => r.copyWith(vin: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.xxl),
        CampoFecha(
          fecha: t.fecha,
          habilitado: !bloqueado,
          onCambio: (f) => ctrl.editar((r) => r.copyWith(fecha: f)),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------------- pasos 2-3 */

class _Fotos extends StatelessWidget {
  const _Fotos({
    required this.titulo,
    required this.detalle,
    required this.fotos,
    required this.onCambio,
    required this.bloqueado,
    this.secundario = false,
  });

  final String titulo;
  final String detalle;
  final List<Foto> fotos;
  final ValueChanged<List<Foto>> onCambio;
  final bool bloqueado;
  final bool secundario;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Encabezado(
            titulo: titulo,
            detalle: detalle,
            secundario: secundario,
          ),
          GaleriaFotos(
            fotos: fotos,
            bloqueado: bloqueado,
            onCambio: onCambio,
          ),
        ],
      );
}

/* ------------------------------------------------------------------ paso 4 */

class _Lugar extends StatelessWidget {
  const _Lugar({
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
  });

  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;

  /// Volver a Taller **limpia** los datos de campo.
  ///
  /// El cálculo del traslado ya exige tipo campo *y* movilidad propia, así que
  /// esto es cinturón y tirantes a propósito: si alguien elige Campo, carga
  /// las vueltas y después vuelve a Taller, esos números no tienen por qué
  /// quedar dando vueltas en el registro.
  void _cambiarTipo(TipoTrabajo tipo) {
    if (tipo == TipoTrabajo.campo) {
      ctrl.editar((t) => t.copyWith(tipo: tipo));
      return;
    }

    campos.vueltas.text = '1';
    campos.precioVuelta.clear();
    campos.ubicacion.clear();
    ctrl.editar((t) => t.copyWith(
          tipo: tipo,
          ubicacion: '',
          movilidad: Movilidad.cliente,
          vueltas: 0,
          precioVuelta: 0,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = ctrl.registro;
    final esCampo = t.tipo == TipoTrabajo.campo;
    final propia = t.movilidad == Movilidad.propia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          titulo: '¿Dónde se hizo?',
          detalle: 'Solo el trabajo en campo puede cobrar traslado.',
        ),
        Row(
          children: [
            Expanded(
              child: _Opcion(
                icono: Icons.handyman_rounded,
                texto: 'En el taller',
                activo: !esCampo,
                onTap:
                    bloqueado ? null : () => _cambiarTipo(TipoTrabajo.taller),
              ),
            ),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: _Opcion(
                icono: Icons.local_shipping_rounded,
                texto: 'En el campo',
                activo: esCampo,
                onTap: bloqueado ? null : () => _cambiarTipo(TipoTrabajo.campo),
              ),
            ),
          ],
        ),
        // La ubicación aparece **solo en campo**. En el taller la respuesta
        // es el taller: preguntarla igual era pedir un dato que ya se sabe, y
        // dejaba el paso con un campo vacío que nadie completaba.
        if (esCampo) ...[
          const SizedBox(height: Espacio.xl),
          Campo(
            etiqueta: 'Dónde fue',
            controlador: campos.ubicacion,
            ejemplo: 'Ej. Planta de Eco Pampa',
            habilitado: !bloqueado,
            validador: Valida.obligatorio('dónde fue'),
            onCambio: (v) => ctrl.editar((r) => r.copyWith(ubicacion: v)),
          ),
          const SizedBox(height: Espacio.xxl),
          Seccion(
            titulo: 'Movilidad',
            child: Row(
              children: [
                Expanded(
                  child: _Opcion(
                    icono: Icons.directions_car_rounded,
                    texto: 'Fui yo',
                    activo: propia,
                    onTap: bloqueado
                        ? null
                        : () => ctrl.editar(
                            (r) => r.copyWith(movilidad: Movilidad.propia)),
                  ),
                ),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: _Opcion(
                    icono: Icons.person_pin_circle_rounded,
                    texto: 'Me llevó el cliente',
                    activo: !propia,
                    onTap: bloqueado
                        ? null
                        : () => ctrl.editar(
                            (r) => r.copyWith(movilidad: Movilidad.cliente)),
                  ),
                ),
              ],
            ),
          ),
          if (propia) ...[
            const SizedBox(height: Espacio.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Campo(
                    etiqueta: 'Vueltas',
                    controlador: campos.vueltas,
                    ejemplo: '1',
                    teclado: TextInputType.number,
                    formateadores: [soloDigitosFormato],
                    habilitado: !bloqueado,
                    validador: Valida.entero(obligatorio: true, minimo: 1),
                    onCambio: (v) => ctrl.editar(
                      (r) => r.copyWith(vueltas: int.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: Campo(
                    etiqueta: 'Precio por vuelta',
                    controlador: campos.precioVuelta,
                    ejemplo: '0.00',
                    teclado:
                        const TextInputType.numberWithOptions(decimal: true),
                    formateadores: [decimalFormato],
                    habilitado: !bloqueado,
                    validador: Valida.precio(obligatorio: true),
                    onCambio: (v) => ctrl.editar(
                      (r) => r.copyWith(precioVuelta: leerNumero(v)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.lg),
            Panel(
              color: Tono.oroSuave,
              padding: const EdgeInsets.all(Espacio.lg),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, size: 20, color: Tono.oro),
                  const SizedBox(width: Espacio.md),
                  Expanded(
                    child: Text(
                      'Se cobra ${soles(ctrl.totales.subTraslado)} de '
                      'traslado, y va dentro de la mano de obra.',
                      style: Tipo.secundario.copyWith(color: Tono.oroTexto),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/* ------------------------------------------------------------------ paso 5 */

class _Diagnostico extends StatelessWidget {
  const _Diagnostico({
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
    this.secundario = false,
  });

  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;
  final bool secundario;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Encabezado(
            titulo: 'Qué encontraste',
            detalle: 'Va tal cual en el reporte de servicio.',
            secundario: secundario,
          ),
          Campo(
            etiqueta: 'Observaciones',
            controlador: campos.observaciones,
            ejemplo: 'Cómo llegó, qué contó el cliente',
            lineas: 4,
            opcional: true,
            habilitado: !bloqueado,
            onCambio: (v) => ctrl.editar((r) => r.copyWith(observaciones: v)),
          ),
          const SizedBox(height: Espacio.lg),
          Campo(
            etiqueta: 'Diagnóstico',
            controlador: campos.diagnostico,
            ejemplo: 'La falla que encontraste',
            lineas: 4,
            opcional: true,
            habilitado: !bloqueado,
            onCambio: (v) => ctrl.editar((r) => r.copyWith(diagnostico: v)),
          ),
        ],
      );
}

/* ------------------------------------------------------------------ paso 6 */

class _ManoDeObra extends StatelessWidget {
  const _ManoDeObra({required this.ctrl, required this.bloqueado});

  final ControladorRegistro ctrl;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Encabezado(
            titulo: 'Qué trabajo hiciste',
            detalle: 'Sin cantidad: un trabajo se cobra por lo que se acordó.',
          ),
          if (!bloqueado) AgregarManoDeObra(onAgregar: ctrl.agregarManoDeObra),
          const SizedBox(height: Espacio.lg),
          TablaItems(
            items: ctrl.registro.trabajosRealizados,
            mostrarCantidad: false,
            vacio: 'Todavía no agregaste ningún trabajo.',
            onEliminar: bloqueado ? null : ctrl.quitarManoDeObra,
          ),
        ],
      );
}

/* ------------------------------------------------------------------ paso 7 */

class _Repuestos extends StatelessWidget {
  const _Repuestos({
    required this.ctrl,
    required this.bloqueado,
    required this.onAviso,
    this.secundario = false,
  });

  final ControladorRegistro ctrl;
  final bool bloqueado;
  final ValueChanged<String> onAviso;
  final bool secundario;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Encabezado(
            titulo: 'Qué repuestos usaste',
            detalle: 'Busca y toca el + — el precio ya está puesto.',
            secundario: secundario,
          ),
          if (!bloqueado)
            SelectorRepuesto(
              onAgregar: (lineas, aviso) {
                ctrl.agregarRepuestos(lineas);
                if (aviso != null) onAviso(aviso);
              },
            ),
          const SizedBox(height: Espacio.lg),
          TablaItems(
            items: ctrl.registro.repuestos,
            mostrarOrigen: true,
            vacio: 'Todavía no agregaste ningún repuesto.',
            onEliminar: bloqueado ? null : ctrl.quitarRepuesto,
            onCambiarCantidad: bloqueado
                ? null
                : (i, delta) async {
                    final aviso = await ctrl.cambiarCantidad(i, delta);
                    if (aviso != null) onAviso(aviso);
                  },
          ),
        ],
      );
}

/* ------------------------------------------------------------------ paso 8 */

class _Recomendaciones extends StatelessWidget {
  const _Recomendaciones({
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
  });

  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final cada = ctrl.registro.recordatorio;
    final hayTexto = ctrl.registro.recomendaciones.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          titulo: 'Qué conviene hacer después',
          detalle: 'Lo que le dices al cliente al entregar, por escrito.',
        ),
        Campo(
          etiqueta: 'Recomendaciones',
          controlador: campos.recomendaciones,
          ejemplo: 'Ej. Revisar rodamientos en 6 meses',
          lineas: 4,
          opcional: true,
          habilitado: !bloqueado,
          // Si va a nacer un recordatorio, el texto deja de ser opcional: es
          // lo único que va a leer dentro de seis meses.
          validador: cada == null
              ? null
              : Valida.obligatorio('el texto de la recomendación'),
          onCambio: (v) => ctrl.editar((r) => r.copyWith(recomendaciones: v)),
        ),
        const SizedBox(height: Espacio.lg),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Agendar recordatorio', style: Tipo.encabezado),
                        const SizedBox(height: 2),
                        Text(
                          'Hereda el cliente, el equipo y este texto.',
                          style: Tipo.nota,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: cada != null,
                    activeThumbColor: Tono.vino,
                    onChanged: bloqueado
                        ? null
                        : (activo) => ctrl.editar((r) => activo
                            ? r.copyWith(
                                recordatorio: const Repeticion.meses(6))
                            : r.copyWith(quitarRecordatorio: true)),
                  ),
                ],
              ),
              if (cada != null) ...[
                const SizedBox(height: Espacio.lg),
                SelectorRepeticion(
                  valor: cada,
                  bloqueado: bloqueado,
                  desde: ctrl.registro.fecha.isEmpty
                      ? hoyISO()
                      : ctrl.registro.fecha,
                  onCambio: (v) => ctrl.editar((r) => v == null
                      ? r.copyWith(quitarRecordatorio: true)
                      : r.copyWith(recordatorio: v)),
                ),
                if (!hayTexto) ...[
                  const SizedBox(height: Espacio.md),
                  Text(
                    'Escribe arriba qué hay que revisar: es lo que vas a leer '
                    'cuando salte el aviso.',
                    style: Tipo.nota.copyWith(color: Tono.vinoTexto),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ paso 9 */

class _Totales extends StatelessWidget {
  const _Totales({
    required this.ctrl,
    required this.campos,
    required this.bloqueado,
  });

  final ControladorRegistro ctrl;
  final CamposWizard campos;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final separado = ctrl.registro.vistaDoc == VistaDoc.separado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          titulo: 'Cuánto se cobra',
          detalle: 'Los precios ya llevan el IGV adentro.',
        ),
        ResumenTotales(totales: ctrl.totales),
        const SizedBox(height: Espacio.xl),
        Campo(
          etiqueta: 'Descuento',
          controlador: campos.descuento,
          ejemplo: '0.00',
          opcional: true,
          teclado: const TextInputType.numberWithOptions(decimal: true),
          formateadores: [decimalFormato],
          ayuda: 'Se resta del total, antes de desagregar el IGV.',
          habilitado: !bloqueado,
          validador: Valida.descuento(() => ctrl.totales.subtotal),
          onCambio: (v) =>
              ctrl.editar((r) => r.copyWith(descuento: leerNumero(v))),
        ),
        const SizedBox(height: Espacio.xxl),
        Seccion(
          titulo: 'Cómo se emite',
          child: Column(
            children: [
              _OpcionAncha(
                icono: Icons.description_rounded,
                texto: 'Una sola boleta',
                detalle: 'Mano de obra y repuestos juntos.',
                activo: !separado,
                onTap: bloqueado
                    ? null
                    : () =>
                        ctrl.editar((r) => r.copyWith(vistaDoc: VistaDoc.junto)),
              ),
              const SizedBox(height: Espacio.md),
              _OpcionAncha(
                icono: Icons.splitscreen_rounded,
                texto: 'Dos boletas separadas',
                detalle: 'Mano de obra por un lado, repuestos por el otro.',
                activo: separado,
                onTap: bloqueado
                    ? null
                    : () => ctrl
                        .editar((r) => r.copyWith(vistaDoc: VistaDoc.separado)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ piezas */

/// Opción cuadrada, de a dos por fila.
///
/// Lo elegido se llena de color y lo no elegido queda blanco: con dos opciones
/// del tamaño de media pantalla no hace falta un radio button, y el peso de la
/// superficie dice cuál está activa desde el otro lado del taller.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenido = AnimatedContainer(
      duration: duracion(context, Movimiento.micro),
      curve: Movimiento.salida,
      padding: const EdgeInsets.symmetric(
        horizontal: Espacio.md,
        vertical: Espacio.xl,
      ),
      decoration: BoxDecoration(
        color: activo ? Tono.vino : Tono.fondo,
        borderRadius: Redondeo.brNormal,
      ),
      child: Column(
        children: [
          Icon(
            icono,
            size: 26,
            color: activo ? Tono.oroClaro : Tono.texto2,
          ),
          const SizedBox(height: Espacio.md),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Tipo.encabezado.copyWith(
              fontSize: 14.5,
              color: activo ? Tono.textoInverso : Tono.texto,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return contenido;
    return Pulsable(onTap: onTap, escala: 0.97, child: contenido);
  }
}

/// La misma opción, a lo ancho y con una línea de explicación.
class _OpcionAncha extends StatelessWidget {
  const _OpcionAncha({
    required this.icono,
    required this.texto,
    required this.detalle,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final String detalle;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenido = AnimatedContainer(
      duration: duracion(context, Movimiento.micro),
      curve: Movimiento.salida,
      padding: const EdgeInsets.all(Espacio.lg),
      decoration: BoxDecoration(
        color: activo ? Tono.vino : Tono.fondo,
        borderRadius: Redondeo.brNormal,
      ),
      child: Row(
        children: [
          Icon(icono, size: 24, color: activo ? Tono.oroClaro : Tono.texto2),
          const SizedBox(width: Espacio.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: Tipo.encabezado.copyWith(
                    color: activo ? Tono.textoInverso : Tono.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: Tipo.nota.copyWith(
                    color: activo ? Tono.textoInverso2 : Tono.texto2,
                  ),
                ),
              ],
            ),
          ),
          if (activo)
            const Icon(Icons.check_circle_rounded,
                size: 20, color: Tono.oroClaro),
        ],
      ),
    );

    if (onTap == null) return contenido;
    return Pulsable(onTap: onTap, escala: 0.985, child: contenido);
  }
}
