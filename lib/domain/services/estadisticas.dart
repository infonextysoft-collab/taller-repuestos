import '../../core/utils/dinero.dart';
import '../../core/utils/texto.dart';
import '../entities/trabajo.dart';

/// Cuánto se movió un repuesto: unidades, lo cobrado y lo que dejó.
class VentasDeRepuesto {
  const VentasDeRepuesto({
    required this.nombre,
    required this.unidades,
    required this.cobrado,
    required this.costo,
    required this.sinCosto,
    this.inventarioId,
  });

  final String nombre;
  final int unidades;
  final double cobrado;

  /// Lo que costaron las unidades que sí lo dicen.
  final double costo;

  /// Cuántas líneas no lo dicen.
  final int sinCosto;

  final int? inventarioId;

  double get ganancia => redondear(cobrado - costo);
  bool get completa => sinCosto == 0;
}

/// Junta las líneas de repuesto de todos los trabajos, por repuesto.
///
/// **Se cuenta desde los trabajos y no desde una tabla de movimientos.** Los
/// trabajos son la fuente: si uno se edita o se borra, esto se entera solo. Un
/// registro paralelo habría que corregirlo a mano en cada uno de esos casos, y
/// ahí es donde las cuentas se van despegando de la realidad.
///
/// Se agrupa por **nombre** y no por id: así las unidades que se compraron
/// afuera porque no alcanzaba el stock suman con las que salieron del
/// inventario, que para el taller son el mismo repuesto.
List<VentasDeRepuesto> ventasPorRepuesto(List<Trabajo> trabajos) {
  final unidades = <String, int>{};
  final cobrado = <String, double>{};
  final costo = <String, double>{};
  final sinCosto = <String, int>{};
  final nombres = <String, String>{};
  final ids = <String, int>{};

  for (final t in trabajos) {
    for (final linea in t.repuestos) {
      final clave = normalizar(linea.desc);
      if (clave.isEmpty) continue;

      unidades[clave] = (unidades[clave] ?? 0) + linea.cantidad;
      cobrado[clave] = (cobrado[clave] ?? 0) + linea.importe;
      nombres.putIfAbsent(clave, () => linea.desc.trim());

      final id = linea.inventarioId;
      if (id != null) ids.putIfAbsent(clave, () => id);

      final total = linea.costoTotal;
      if (total == null) {
        sinCosto[clave] = (sinCosto[clave] ?? 0) + 1;
      } else {
        costo[clave] = (costo[clave] ?? 0) + total;
      }
    }
  }

  final lista = [
    for (final clave in unidades.keys)
      VentasDeRepuesto(
        nombre: nombres[clave] ?? clave,
        unidades: unidades[clave] ?? 0,
        cobrado: redondear(cobrado[clave] ?? 0),
        costo: redondear(costo[clave] ?? 0),
        sinCosto: sinCosto[clave] ?? 0,
        inventarioId: ids[clave],
      ),
  ];

  // Lo más vendido arriba; a igual cantidad, lo que más dejó.
  lista.sort((a, b) {
    final porUnidades = b.unidades.compareTo(a.unidades);
    return porUnidades != 0 ? porUnidades : b.ganancia.compareTo(a.ganancia);
  });

  return lista;
}

/// Lo vendido de un repuesto puntual. `null` si nunca salió en un trabajo.
VentasDeRepuesto? ventasDe(List<Trabajo> trabajos, String nombre) {
  final buscado = normalizar(nombre);
  if (buscado.isEmpty) return null;

  for (final v in ventasPorRepuesto(trabajos)) {
    if (normalizar(v.nombre) == buscado) return v;
  }
  return null;
}
