import 'package:flutter/foundation.dart';

import '../../core/utils/fechas.dart';
import '../../domain/entities/linea.dart';
import '../../domain/entities/totales.dart';
import '../../domain/entities/trabajo.dart';
import '../../domain/repositories/inventario_repository.dart';
import '../../domain/repositories/recordatorios_repository.dart';
import '../../domain/repositories/trabajos_repository.dart';
import '../../domain/services/calculadora_totales.dart';

/// El registro que se está editando: lo comparten la venta simple y el wizard.
///
/// Vive en la capa de presentación y habla solo con los contratos de
/// repositorio. Es quien sabe dos cosas que ninguna pantalla debería repetir:
///
///   1. El registro **nace en la base** apenas hay algo que guardar, así se
///      puede cerrar la app y volver después sin perder nada.
///   2. El stock se mueve al agregar y quitar cada línea, así que si alguien
///      abandona el formulario hay que **dejar el inventario como estaba**.
class ControladorRegistro extends ChangeNotifier {
  ControladorRegistro(this._trabajos, this._inventario, this._recordatorios);


  final TrabajosRepository _trabajos;
  final InventarioRepository _inventario;
  final RecordatoriosRepository _recordatorios;

  Trabajo _registro = const Trabajo();

  /// Las líneas que ya tenía al abrir. En un alta nueva es la lista vacía, y
  /// la misma función de restaurar devuelve todo: no hay dos caminos.
  List<LineaRepuesto> _originales = const [];

  bool _hayCambios = false;
  bool _guardando = false;

  Trabajo get registro => _registro;
  bool get hayCambios => _hayCambios;
  bool get guardando => _guardando;
  bool get esNuevo => _registro.id == null;

  /// Los totales de lo que hay ahora en pantalla, recalculados en vivo.
  Totales get totales => calculadora.calcular(_registro);

  /// Un paso ya guardado queda en solo lectura hasta darle "Editar".
  bool pasoBloqueado(int paso) => _registro.pasosGuardados.contains(paso);

  /* ---------------------------------------------------------------- alta */

  void empezar(TipoTrabajo tipo) {
    _registro = Trabajo(tipo: tipo, fecha: hoyISO());
    _originales = const [];
    _hayCambios = false;
    notifyListeners();
  }

  Future<void> cargar(int id) async {
    final encontrado = await _trabajos.obtener(id);
    if (encontrado == null) return;

    _registro = encontrado;
    _originales = List.of(encontrado.repuestos);
    _hayCambios = false;
    notifyListeners();
  }

  /* -------------------------------------------------------------- edición */

  /// Cambia el registro en memoria. No toca la base: eso lo hace [guardar].
  void editar(Trabajo Function(Trabajo actual) cambio) {
    _registro = cambio(_registro);
    _hayCambios = true;
    notifyListeners();
  }

  void agregarManoDeObra(LineaMano linea) => editar(
        (t) => t.copyWith(trabajosRealizados: [...t.trabajosRealizados, linea]),
      );

  void quitarManoDeObra(int indice) => editar(
        (t) => t.copyWith(
          trabajosRealizados: [...t.trabajosRealizados]..removeAt(indice),
        ),
      );

  void agregarRepuestos(List<LineaRepuesto> lineas) {
    if (lineas.isEmpty) return;

    editar((t) {
      final actuales = [...t.repuestos];

      // Si ya está la misma línea (mismo repuesto y mismo precio), se le suma
      // la cantidad en vez de repetir el renglón: en el papel, "3 × BUJIA" se
      // lee mejor que tres líneas de "1 × BUJIA".
      for (final nueva in lineas) {
        final i = actuales.indexWhere((l) =>
            l.origen == nueva.origen &&
            l.inventarioId == nueva.inventarioId &&
            l.desc == nueva.desc &&
            l.precio == nueva.precio);

        if (i >= 0) {
          actuales[i] = actuales[i]
              .copyWith(cantidad: actuales[i].cantidad + nueva.cantidad);
        } else {
          actuales.add(nueva);
        }
      }

      return t.copyWith(repuestos: actuales);
    });
  }

  /// Quitar una línea devuelve al stock lo que había salido.
  Future<void> quitarRepuesto(int indice) async {
    final linea = _registro.repuestos[indice];
    editar((t) => t.copyWith(repuestos: [...t.repuestos]..removeAt(indice)));
    await _inventario.devolverRepuesto(linea);
  }

  /// − y + sobre una línea ya cargada. Mueve el stock igual que agregarla o
  /// quitarla, porque para el inventario es exactamente lo mismo.
  Future<String?> cambiarCantidad(int indice, int delta) async {
    final linea = _registro.repuestos[indice];

    if (delta < 0) {
      if (linea.cantidad <= 1) {
        await quitarRepuesto(indice);
        return null;
      }
      editar((t) {
        final lineas = [...t.repuestos];
        lineas[indice] = linea.copyWith(cantidad: linea.cantidad - 1);
        return t.copyWith(repuestos: lineas);
      });
      await _inventario.devolverRepuesto(linea.copyWith(cantidad: 1));
      return null;
    }

    // Sumar una unidad pasa por la misma puerta que agregarla de cero: si no
    // hay stock, se divide sola y avisa.
    final resultado = await _inventario.agregarRepuesto(
      inventarioId: linea.inventarioId,
      desc: linea.desc,
      cant: 1,
      precio: linea.precio,
    );
    agregarRepuestos(resultado.lineas);
    return resultado.aviso;
  }

  /* ------------------------------------------------------------- guardado */

  /// Crea el registro la primera vez y lo actualiza de ahí en más. Nunca
  /// duplica: siempre es el mismo id.
  Future<Trabajo> guardar() async {
    _guardando = true;
    notifyListeners();

    try {
      _registro = _registro.id == null
          ? await _trabajos.crear(_registro)
          : await _trabajos.actualizar(_registro);
      _originales = List.of(_registro.repuestos);
      _hayCambios = false;
      return _registro;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// Cierra el paso `paso` y todos los anteriores.
  Future<void> guardarPaso(int paso) async {
    await guardar();
    _registro = await _trabajos.guardarPasosHasta(_registro.id!, paso);
    notifyListeners();
  }

  Future<void> reabrirPaso(int paso) async {
    if (_registro.id == null) return;
    _registro = await _trabajos.editarPaso(_registro.id!, paso);
    notifyListeners();
  }

  /// Cierra el registro y, si se pidió, deja creado el recordatorio.
  Future<Trabajo> terminar() async {
    await guardar();

    // Sin texto no hay recordatorio que crear: quedaría un aviso en blanco
    // sonando dentro de tres meses sin decir de qué era.
    final cada = _registro.recordatorio;
    if (cada != null &&
        cada.valida &&
        _registro.recomendaciones.trim().isNotEmpty) {
      await _recordatorios.crearDesdeTrabajo(_registro, cada);
    }

    _registro = await _trabajos.terminar(_registro.id!);
    _hayCambios = false;
    notifyListeners();
    return _registro;
  }

  /// Salir sin guardar: el inventario vuelve al estado que tenía al abrir la
  /// pantalla, y un registro que nunca llegó a la base no deja rastro.
  Future<void> descartar() async {
    await _inventario.restaurarRepuestos(_registro.repuestos, _originales);
    _hayCambios = false;
  }
}
