import '../../core/utils/fechas.dart';

/// En qué unidad se cuenta un intervalo de repetición.
enum UnidadRepeticion { dias, semanas, meses, anios }

extension UnidadRepeticionX on UnidadRepeticion {
  String get singular => switch (this) {
        UnidadRepeticion.dias => 'día',
        UnidadRepeticion.semanas => 'semana',
        UnidadRepeticion.meses => 'mes',
        UnidadRepeticion.anios => 'año',
      };

  String get plural => switch (this) {
        UnidadRepeticion.dias => 'días',
        UnidadRepeticion.semanas => 'semanas',
        UnidadRepeticion.meses => 'meses',
        UnidadRepeticion.anios => 'años',
      };

  /// Para las insignias, donde no entra el texto largo.
  String get inicial => switch (this) {
        UnidadRepeticion.dias => 'd',
        UnidadRepeticion.semanas => 'sem',
        UnidadRepeticion.meses => 'm',
        UnidadRepeticion.anios => 'a',
      };
}

/// Cada cuánto vuelve un mantenimiento.
///
/// Existe porque las tres opciones fijas que había antes —3, 6 y 12 meses— eran
/// una suposición sobre el negocio de otra persona. Un filtro de aceite puede
/// ser cada 15 días y una revisión general cada 2 años; el que sabe cuál es
/// cuál es quien atiende el taller, no la app.
///
/// La cuenta se hace **en la unidad elegida**, no traduciendo todo a días: un
/// mantenimiento "cada 3 meses" pactado un 31 de enero cae el 30 de abril, no
/// noventa días después.
class Repeticion {
  const Repeticion(this.cada, this.unidad);

  const Repeticion.meses(this.cada) : unidad = UnidadRepeticion.meses;

  final int cada;
  final UnidadRepeticion unidad;

  bool get valida => cada > 0;

  /// "Cada 3 meses" · "Cada mes"
  String get etiqueta =>
      cada == 1 ? 'Cada ${unidad.singular}' : 'Cada $cada ${unidad.plural}';

  /// "3 m" · "15 d"
  String get corta => '$cada ${unidad.inicial}';

  /// La próxima fecha a partir de una dada.
  String siguiente(String desdeISO) => switch (unidad) {
        UnidadRepeticion.dias => sumarDias(desdeISO, cada),
        UnidadRepeticion.semanas => sumarDias(desdeISO, cada * 7),
        UnidadRepeticion.meses => sumarMeses(desdeISO, cada),
        UnidadRepeticion.anios => sumarMeses(desdeISO, cada * 12),
      };

  /// Lee las dos columnas de la base. Devuelve `null` cuando no se repite.
  ///
  /// Cae a la columna vieja `repetirMeses` para los recordatorios creados antes
  /// de que existiera la unidad: interpretarlos como meses es exactamente lo
  /// que eran.
  static Repeticion? deFilas(Object? cada, Object? unidad, Object? mesesViejo) {
    final n = (cada as num?)?.toInt() ?? (mesesViejo as num?)?.toInt();
    if (n == null || n <= 0) return null;

    final nombre = unidad?.toString();
    return Repeticion(
      n,
      UnidadRepeticion.values.firstWhere(
        (u) => u.name == nombre,
        orElse: () => UnidadRepeticion.meses,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Repeticion && other.cada == cada && other.unidad == unidad;

  @override
  int get hashCode => Object.hash(cada, unidad);
}
