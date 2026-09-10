import 'dart:convert';

import 'linea.dart';
import 'repeticion.dart';
import 'totales.dart';

/// Qué clase de registro es. Manda sobre el prefijo del código, sobre si hay
/// reporte de servicio y sobre si se cobra traslado.
enum TipoTrabajo { taller, campo, venta }

extension TipoTrabajoX on TipoTrabajo {
  String get etiqueta => switch (this) {
        TipoTrabajo.taller => 'Trabajo en taller',
        TipoTrabajo.campo => 'Trabajo en campo',
        TipoTrabajo.venta => 'Venta de repuestos',
      };

  /// Cómo se nombra el servicio dentro del documento.
  String get nombreServicio => switch (this) {
        TipoTrabajo.taller => 'Servicio en taller',
        TipoTrabajo.campo => 'Servicio en campo',
        TipoTrabajo.venta => 'Venta de repuestos',
      };

  String get prefijoCodigo => this == TipoTrabajo.venta ? 'VTA' : 'REP';

  /// Una venta simple no lleva reporte: no hubo servicio que reportar.
  bool get llevaReporte => this != TipoTrabajo.venta;
}

enum EstadoTrabajo { pendiente, terminado }

enum Movilidad { propia, cliente }

/// Una boleta con todo, o dos separadas (mano de obra y repuestos).
enum VistaDoc { junto, separado }

T _enumDe<T extends Enum>(List<T> valores, Object? raw, T porDefecto) {
  final s = raw?.toString();
  for (final v in valores) {
    if (v.name == s) return v;
  }
  return porDefecto;
}

/// Un registro del historial: una venta simple o un trabajo (taller / campo).
///
/// El estado `pendiente` es lo que permite el flujo real: registrar cliente y
/// fotos de ingreso, irse a trabajar, y volver horas después a completar el
/// resto sin perder nada.
class Trabajo {
  const Trabajo({
    this.id,
    this.codigo = '',
    this.tipo = TipoTrabajo.taller,
    this.estado = EstadoTrabajo.pendiente,
    this.fecha = '',
    this.cliente = '',
    this.ruc = '',
    this.facturarA = '',
    this.equipo = '',
    this.modelo = '',
    this.ubicacion = '',
    this.movilidad = Movilidad.cliente,
    this.vueltas = 0,
    this.precioVuelta = 0,
    this.fotosIngreso = const [],
    this.fotosEntrega = const [],
    this.observaciones = '',
    this.diagnostico = '',
    this.trabajosRealizados = const [],
    this.repuestos = const [],
    this.recomendaciones = '',
    this.recordatorio,
    this.descuento = 0,
    this.vistaDoc = VistaDoc.junto,
    this.totales = const Totales(),
    this.pasosGuardados = const [],
  });

  final int? id;
  final String codigo;
  final TipoTrabajo tipo;
  final EstadoTrabajo estado;

  /// ISO corto, sin hora ni zona horaria.
  final String fecha;

  final String cliente;
  final String ruc;
  final String facturarA;
  final String equipo;
  final String modelo;
  final String ubicacion;

  final Movilidad movilidad;
  final int vueltas;
  final double precioVuelta;

  /// Rutas de archivo de las fotos ya comprimidas.
  final List<String> fotosIngreso;
  final List<String> fotosEntrega;

  final String observaciones;
  final String diagnostico;

  final List<LineaMano> trabajosRealizados;
  final List<LineaRepuesto> repuestos;

  final String recomendaciones;

  /// Cada cuánto agendar el mantenimiento al cerrar. `null` = no agendar.
  final Repeticion? recordatorio;

  final double descuento;
  final VistaDoc vistaDoc;

  /// Congelados al terminar: un documento entregado no cambia de importe
  /// porque alguien editó un precio del inventario tres meses después.
  final Totales totales;

  /// Qué pasos del wizard quedaron cerrados (solo lectura hasta "Editar").
  final List<int> pasosGuardados;

  /// Derivado, nunca se guarda como decisión aparte.
  bool get cobraTraslado =>
      tipo == TipoTrabajo.campo && movilidad == Movilidad.propia;

  String get aQuienFacturar => facturarA.trim().isEmpty ? cliente : facturarA;

  bool get estaTerminado => estado == EstadoTrabajo.terminado;

  Trabajo copyWith({
    int? id,
    String? codigo,
    TipoTrabajo? tipo,
    EstadoTrabajo? estado,
    String? fecha,
    String? cliente,
    String? ruc,
    String? facturarA,
    String? equipo,
    String? modelo,
    String? ubicacion,
    Movilidad? movilidad,
    int? vueltas,
    double? precioVuelta,
    List<String>? fotosIngreso,
    List<String>? fotosEntrega,
    String? observaciones,
    String? diagnostico,
    List<LineaMano>? trabajosRealizados,
    List<LineaRepuesto>? repuestos,
    String? recomendaciones,
    Repeticion? recordatorio,
    bool quitarRecordatorio = false,
    double? descuento,
    VistaDoc? vistaDoc,
    Totales? totales,
    List<int>? pasosGuardados,
  }) =>
      Trabajo(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        tipo: tipo ?? this.tipo,
        estado: estado ?? this.estado,
        fecha: fecha ?? this.fecha,
        cliente: cliente ?? this.cliente,
        ruc: ruc ?? this.ruc,
        facturarA: facturarA ?? this.facturarA,
        equipo: equipo ?? this.equipo,
        modelo: modelo ?? this.modelo,
        ubicacion: ubicacion ?? this.ubicacion,
        movilidad: movilidad ?? this.movilidad,
        vueltas: vueltas ?? this.vueltas,
        precioVuelta: precioVuelta ?? this.precioVuelta,
        fotosIngreso: fotosIngreso ?? this.fotosIngreso,
        fotosEntrega: fotosEntrega ?? this.fotosEntrega,
        observaciones: observaciones ?? this.observaciones,
        diagnostico: diagnostico ?? this.diagnostico,
        trabajosRealizados: trabajosRealizados ?? this.trabajosRealizados,
        repuestos: repuestos ?? this.repuestos,
        recomendaciones: recomendaciones ?? this.recomendaciones,
        recordatorio: quitarRecordatorio
            ? null
            : (recordatorio ?? this.recordatorio),
        descuento: descuento ?? this.descuento,
        vistaDoc: vistaDoc ?? this.vistaDoc,
        totales: totales ?? this.totales,
        pasosGuardados: pasosGuardados ?? this.pasosGuardados,
      );

  /* ---------------------------------------------------------------------
     Persistencia. Las listas anidadas van como JSON en una columna TEXT: el
     orden de las líneas importa para el documento, y así se conserva solo.
     --------------------------------------------------------------------- */

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'codigo': codigo,
        'tipo': tipo.name,
        'estado': estado.name,
        'fecha': fecha,
        'cliente': cliente,
        'ruc': ruc,
        'facturarA': facturarA,
        'equipo': equipo,
        'modelo': modelo,
        'ubicacion': ubicacion,
        'movilidad': movilidad.name,
        'vueltas': vueltas,
        'precioVuelta': precioVuelta,
        'cobraTraslado': cobraTraslado ? 1 : 0,
        'fotosIngreso': jsonEncode(fotosIngreso),
        'fotosEntrega': jsonEncode(fotosEntrega),
        'observaciones': observaciones,
        'diagnostico': diagnostico,
        'trabajosRealizados':
            jsonEncode(trabajosRealizados.map((l) => l.toJson()).toList()),
        'repuestos': jsonEncode(repuestos.map((l) => l.toJson()).toList()),
        'recomendaciones': recomendaciones,
        'recordatorioCada': recordatorio?.cada,
        'recordatorioUnidad': recordatorio?.unidad.name,
        'descuento': descuento,
        'vistaDoc': vistaDoc.name,
        'totales': jsonEncode(totales.toJson()),
        'pasosGuardados': jsonEncode(pasosGuardados),
      };

  static List<T> _lista<T>(Object? raw, T Function(Map<String, dynamic>) leer) {
    if (raw == null) return const [];
    final decodificado = jsonDecode(raw.toString());
    if (decodificado is! List) return const [];
    return decodificado
        .whereType<Map>()
        .map((m) => leer(Map<String, dynamic>.from(m)))
        .toList();
  }

  static List<String> _fotos(Object? raw) {
    if (raw == null) return const [];
    final d = jsonDecode(raw.toString());
    return d is List ? d.map((e) => e.toString()).toList() : const [];
  }

  factory Trabajo.fromRow(Map<String, Object?> r) => Trabajo(
        id: (r['id'] as num?)?.toInt(),
        codigo: (r['codigo'] ?? '').toString(),
        tipo: _enumDe(TipoTrabajo.values, r['tipo'], TipoTrabajo.taller),
        estado:
            _enumDe(EstadoTrabajo.values, r['estado'], EstadoTrabajo.pendiente),
        fecha: (r['fecha'] ?? '').toString(),
        cliente: (r['cliente'] ?? '').toString(),
        ruc: (r['ruc'] ?? '').toString(),
        facturarA: (r['facturarA'] ?? '').toString(),
        equipo: (r['equipo'] ?? '').toString(),
        modelo: (r['modelo'] ?? '').toString(),
        ubicacion: (r['ubicacion'] ?? '').toString(),
        movilidad: _enumDe(Movilidad.values, r['movilidad'], Movilidad.cliente),
        vueltas: (r['vueltas'] as num?)?.toInt() ?? 0,
        precioVuelta: (r['precioVuelta'] as num?)?.toDouble() ?? 0,
        fotosIngreso: _fotos(r['fotosIngreso']),
        fotosEntrega: _fotos(r['fotosEntrega']),
        observaciones: (r['observaciones'] ?? '').toString(),
        diagnostico: (r['diagnostico'] ?? '').toString(),
        trabajosRealizados: _lista(r['trabajosRealizados'], LineaMano.fromJson),
        repuestos: _lista(r['repuestos'], LineaRepuesto.fromJson),
        recomendaciones: (r['recomendaciones'] ?? '').toString(),
        recordatorio: Repeticion.deFilas(
          r['recordatorioCada'],
          r['recordatorioUnidad'],
          r['recordatorioMeses'],
        ),
        descuento: (r['descuento'] as num?)?.toDouble() ?? 0,
        vistaDoc: _enumDe(VistaDoc.values, r['vistaDoc'], VistaDoc.junto),
        totales: r['totales'] == null
            ? const Totales()
            : Totales.fromJson(
                Map<String, dynamic>.from(jsonDecode(r['totales'].toString()))),
        pasosGuardados: r['pasosGuardados'] == null
            ? const []
            : (jsonDecode(r['pasosGuardados'].toString()) as List)
                .map((e) => (e as num).toInt())
                .toList(),
      );
}
