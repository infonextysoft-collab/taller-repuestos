import 'repeticion.dart';

/// Ciclo de vida de un recordatorio.
///
/// ```
///         crear
///           ↓
///     [ pendiente ] ── pasa la fecha ──→ [ vencido ]
///           │                                 │
///           └────── marcarCumplido ───────────┘
///                         ↓
///                   [ cumplido ]   final, no vuelve atrás
///                         │
///                         └─ si `repite != null`, nace uno NUEVO pendiente
///                            con fecha = programada + el intervalo
/// ```
enum EstadoRecordatorio { pendiente, vencido, cumplido }

enum OrigenRecordatorio { automatico, manual }

/// Un mantenimiento o aviso a futuro.
class Recordatorio {
  const Recordatorio({
    this.id,
    required this.descripcion,
    required this.fecha,
    this.repite,
    this.estado = EstadoRecordatorio.pendiente,
    this.origen = OrigenRecordatorio.manual,
    this.importante = false,
    this.trabajoId,
    this.cliente,
    this.equipo,
  });

  final int? id;
  final String descripcion;

  /// Próxima fecha, ISO corto.
  final String fecha;

  /// `null` = no se repite. Es un intervalo libre: 15 días, 2 meses, 1 año.
  final Repeticion? repite;

  final EstadoRecordatorio estado;
  final OrigenRecordatorio origen;

  /// Marcado a mano por quien atiende el taller. No lo decide la app: para
  /// un negocio la revisión anual de un cliente grande pesa más que diez
  /// cambios de filtro, y eso no se deduce de la fecha ni del importe.
  final bool importante;

  /// De qué trabajo nació, si nació de uno.
  final int? trabajoId;
  final String? cliente;
  final String? equipo;

  bool get seRepite => repite != null && repite!.valida;
  bool get cumplido => estado == EstadoRecordatorio.cumplido;

  Recordatorio copyWith({
    int? id,
    String? descripcion,
    String? fecha,
    Repeticion? repite,
    bool quitarRepeticion = false,
    EstadoRecordatorio? estado,
    OrigenRecordatorio? origen,
    bool? importante,
    int? trabajoId,
    String? cliente,
    String? equipo,
  }) =>
      Recordatorio(
        id: id ?? this.id,
        descripcion: descripcion ?? this.descripcion,
        fecha: fecha ?? this.fecha,
        repite: quitarRepeticion ? null : (repite ?? this.repite),
        estado: estado ?? this.estado,
        origen: origen ?? this.origen,
        importante: importante ?? this.importante,
        trabajoId: trabajoId ?? this.trabajoId,
        cliente: cliente ?? this.cliente,
        equipo: equipo ?? this.equipo,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'descripcion': descripcion.trim(),
        'fecha': fecha,
        'repetirCada': repite?.cada,
        'repetirUnidad': repite?.unidad.name,
        'estado': estado.name,
        'origen': origen.name,
        'importante': importante ? 1 : 0,
        'trabajoId': trabajoId,
        'cliente': cliente,
        'equipo': equipo,
      };

  factory Recordatorio.fromRow(Map<String, Object?> r) => Recordatorio(
        id: (r['id'] as num?)?.toInt(),
        descripcion: (r['descripcion'] ?? '').toString(),
        fecha: (r['fecha'] ?? '').toString(),
        repite: Repeticion.deFilas(
          r['repetirCada'],
          r['repetirUnidad'],
          r['repetirMeses'],
        ),
        estado: EstadoRecordatorio.values.firstWhere(
          (e) => e.name == r['estado'],
          orElse: () => EstadoRecordatorio.pendiente,
        ),
        origen: OrigenRecordatorio.values.firstWhere(
          (e) => e.name == r['origen'],
          orElse: () => OrigenRecordatorio.manual,
        ),
        importante: ((r['importante'] as num?)?.toInt() ?? 0) == 1,
        trabajoId: (r['trabajoId'] as num?)?.toInt(),
        cliente: r['cliente']?.toString(),
        equipo: r['equipo']?.toString(),
      );
}

/// Los recordatorios de un mes, para la lista agrupada.
class GrupoRecordatorios {
  const GrupoRecordatorios(this.mes, this.items);

  /// Clave `"2026-08"`.
  final String mes;
  final List<Recordatorio> items;
}
