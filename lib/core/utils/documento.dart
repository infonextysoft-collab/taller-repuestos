/// Validación de DNI y RUC peruanos.
///
/// El campo es opcional en casi todas las pantallas, así que "vacío" nunca es
/// un error. Lo que sí se atrapa es el número escrito a medias o mal copiado:
/// un RUC con un dígito cambiado entra igual en un campo de texto libre y
/// después aparece impreso en una boleta.
library;

const int _largoDni = 8;
const int _largoRuc = 11;

/// Prefijos válidos: persona natural, no domiciliado y jurídica.
const List<String> prefijosRuc = ['10', '15', '17', '20'];

/// Pesos del módulo 11 sobre los primeros 10 dígitos.
const List<int> _pesosRuc = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];

enum EstadoDocumento { vacio, escribiendo, valido, invalido }

enum TipoDocumento { dni, ruc }

class RevisionDocumento {
  const RevisionDocumento(this.estado, this.tipo, this.mensaje);

  final EstadoDocumento estado;
  final TipoDocumento? tipo;
  final String mensaje;

  /// Vacío y a medio escribir no bloquean el guardado; mal escrito sí.
  bool get aceptable => estado != EstadoDocumento.invalido;
}

String _faltan(int n) => n == 1 ? 'falta 1 dígito' : 'faltan $n dígitos';

/// Deja solo dígitos: la gente pega números con guiones, puntos y espacios.
String soloDigitos(String? valor) =>
    (valor ?? '').replaceAll(RegExp(r'\D'), '');

/// Dígito verificador de los primeros 10 dígitos de un RUC.
int verificadorRuc(String diez) {
  var suma = 0;
  for (var i = 0; i < 10; i++) {
    suma += (int.tryParse(diez[i]) ?? 0) * _pesosRuc[i];
  }
  final resto = 11 - (suma % 11);
  if (resto == 10) return 0;
  if (resto == 11) return 1;
  return resto;
}

/// Estado de un documento **mientras se escribe**.
///
/// Devuelve un estado en vez de un booleano porque escribir `204` no es un
/// error, es un RUC a medio escribir: marcarlo en rojo mientras la persona
/// teclea la entrena a ignorar todos los avisos.
RevisionDocumento revisarDocumento(String? valor, {bool soloRuc = false}) {
  final d = soloDigitos(valor);

  if (d.isEmpty) {
    return RevisionDocumento(
      EstadoDocumento.vacio,
      null,
      soloRuc ? 'RUC de 11 dígitos.' : 'DNI (8 dígitos) o RUC (11).',
    );
  }

  // El prefijo decide el tipo apenas hay dos dígitos: así el mensaje acompaña
  // desde el principio.
  final pareceRuc =
      soloRuc || (d.length >= 2 && prefijosRuc.contains(d.substring(0, 2)));

  if (pareceRuc) {
    if (d.length < _largoRuc) {
      return RevisionDocumento(
        EstadoDocumento.escribiendo,
        TipoDocumento.ruc,
        'RUC — ${_faltan(_largoRuc - d.length)}.',
      );
    }
    if (d.length > _largoRuc) {
      return const RevisionDocumento(
          EstadoDocumento.invalido, TipoDocumento.ruc, 'El RUC tiene 11 dígitos.');
    }
    if (!prefijosRuc.contains(d.substring(0, 2))) {
      return const RevisionDocumento(EstadoDocumento.invalido,
          TipoDocumento.ruc, 'Un RUC empieza con 10, 15, 17 o 20.');
    }
    if ((int.tryParse(d[10]) ?? -1) != verificadorRuc(d)) {
      return const RevisionDocumento(EstadoDocumento.invalido,
          TipoDocumento.ruc, 'Ese RUC no existe: revisa los dígitos.');
    }
    return const RevisionDocumento(
        EstadoDocumento.valido, TipoDocumento.ruc, 'RUC válido.');
  }

  if (d.length < _largoDni) {
    return RevisionDocumento(
      EstadoDocumento.escribiendo,
      TipoDocumento.dni,
      'DNI — ${_faltan(_largoDni - d.length)}.',
    );
  }
  if (d.length == _largoDni) {
    return const RevisionDocumento(
        EstadoDocumento.valido, TipoDocumento.dni, 'DNI válido.');
  }

  return const RevisionDocumento(
    EstadoDocumento.invalido,
    null,
    'Un DNI tiene 8 dígitos y un RUC 11 (empezando en 10, 15, 17 o 20).',
  );
}

/// ¿Se puede guardar?
bool documentoAceptable(String? valor, {bool soloRuc = false}) =>
    revisarDocumento(valor, soloRuc: soloRuc).aceptable;
