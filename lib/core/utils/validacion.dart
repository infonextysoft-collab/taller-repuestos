import 'documento.dart';

/// Un validador: recibe lo escrito y devuelve el mensaje de error, o `null`
/// si está bien. Es la firma que espera `TextFormField`.
typedef Validador = String? Function(String? valor);

/// Validadores reutilizables.
///
/// Dos criterios que atraviesan todos:
///
///   1. **El mensaje dice qué hacer**, no qué está mal. "Poné el nombre del
///      cliente" sirve; "Campo inválido" obliga a adivinar.
///   2. **Un campo vacío y opcional nunca es un error.** Solo se marca lo que
///      está escrito y no cierra, o lo que falta y hace falta de verdad.
class Valida {
  const Valida._();

  /// Encadena validadores: devuelve el primer error que aparezca.
  ///
  /// El orden importa — primero "falta", después "está mal escrito": decirle
  /// a alguien que su email tiene mal formato cuando todavía no escribió nada
  /// es ruido.
  static Validador todos(List<Validador> validadores) => (valor) {
        for (final validar in validadores) {
          final error = validar(valor);
          if (error != null) return error;
        }
        return null;
      };

  /// El campo tiene que tener algo.
  static Validador obligatorio(String queFalta) => (valor) =>
      (valor ?? '').trim().isEmpty ? 'Falta $queFalta.' : null;

  /// Largo mínimo, para lo que sería inútil guardar a medias.
  static Validador minimo(int caracteres, String queEs) => (valor) {
        final v = (valor ?? '').trim();
        if (v.isEmpty || v.length >= caracteres) return null;
        return '$queEs necesita al menos $caracteres caracteres.';
      };

  /// DNI o RUC peruano. Vacío pasa; a medio escribir **no** pasa al guardar,
  /// porque termina impreso en la boleta.
  static Validador documento({bool soloRuc = false}) => (valor) {
        final revision = revisarDocumento(valor, soloRuc: soloRuc);

        return switch (revision.estado) {
          EstadoDocumento.vacio => null,
          EstadoDocumento.valido => null,
          EstadoDocumento.escribiendo => revision.mensaje,
          EstadoDocumento.invalido => revision.mensaje,
        };
      };

  /// Email. Deliberadamente permisivo: la regla completa del estándar rechaza
  /// direcciones que existen, y acá el email solo se imprime en el documento.
  static Validador email() => (valor) {
        final v = (valor ?? '').trim();
        if (v.isEmpty) return null;

        final formato = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');
        return formato.hasMatch(v) ? null : 'Ese correo está incompleto.';
      };

  /// Teléfono peruano: 6 a 12 dígitos, con o sin separadores.
  static Validador telefono() => (valor) {
        final v = (valor ?? '').trim();
        if (v.isEmpty) return null;

        final digitos = soloDigitos(v);
        if (digitos.length < 6) return 'Ese teléfono es muy corto.';
        if (digitos.length > 12) return 'Ese teléfono es muy largo.';
        return null;
      };

  /// Un importe. Vacío cuenta como cero, salvo que se pida [obligatorio].
  static Validador precio({bool obligatorio = false, double maximo = 999999}) =>
      (valor) {
        final v = (valor ?? '').trim();

        if (v.isEmpty) {
          return obligatorio ? 'Falta el precio.' : null;
        }

        final numero = double.tryParse(v.replaceAll(',', '.'));
        if (numero == null) return 'Escribe solo números.';
        if (numero < 0) return 'El precio no puede ser negativo.';
        if (numero > maximo) return 'Ese precio parece un error.';
        return null;
      };

  /// Una cantidad entera.
  static Validador entero({
    bool obligatorio = false,
    int minimo = 0,
    int maximo = 99999,
  }) =>
      (valor) {
        final v = (valor ?? '').trim();

        if (v.isEmpty) {
          return obligatorio ? 'Falta la cantidad.' : null;
        }

        final numero = int.tryParse(v);
        if (numero == null) return 'Escribe un número entero.';
        if (numero < minimo) return 'No puede ser menor que $minimo.';
        if (numero > maximo) return 'Ese número parece un error.';
        return null;
      };

  /// El descuento de una línea, en porcentaje. Vacío es 0, no un error.
  ///
  /// Se corta en 100: más que eso sería devolverle plata al cliente, y nadie
  /// escribe 120 queriendo decir eso.
  static Validador porcentaje() => (valor) {
        final v = (valor ?? '').trim();
        if (v.isEmpty) return null;

        final numero = double.tryParse(v.replaceAll(',', '.'));
        if (numero == null) return 'Escribe solo números.';
        if (numero < 0) return 'No puede ser negativo.';
        if (numero > 100) return 'Como mucho 100 %.';
        return null;
      };

  /// Un descuento no puede superar lo que se está cobrando.
  static Validador descuento(double Function() subtotal) => (valor) {
        final v = (valor ?? '').trim();
        if (v.isEmpty) return null;

        final numero = double.tryParse(v.replaceAll(',', '.'));
        if (numero == null) return 'Escribe solo números.';
        if (numero < 0) return 'El descuento no puede ser negativo.';
        if (numero > subtotal()) {
          return 'El descuento no puede superar el subtotal.';
        }
        return null;
      };
}
