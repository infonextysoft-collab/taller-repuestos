import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Las contraseñas se guardan como huella, nunca tal cual.
///
/// Mientras la app corrió entera en el teléfono, la clave vivía en texto plano:
/// el login era una traba de uso y no había nada del otro lado. Con la cuenta
/// de correo eso cambió — esa contraseña ahora abre algo fuera del teléfono, y
/// mucha gente usa la misma en todos lados. Abrir el archivo de la base no
/// puede alcanzar para leerla.
///
/// Es PBKDF2 con HMAC-SHA256, el estándar para sacar una huella de una
/// contraseña. Es lento **a propósito**: quien se robe la huella tiene que
/// pagar esas vueltas por cada contraseña que pruebe.

/// Cuántas vueltas por huella. Se guarda junto a cada una, así se puede subir
/// más adelante sin invalidar las que ya existen.
const int kVueltasClave = 60000;

/// En el navegador el cálculo corre en el mismo hilo que la pantalla y tarda
/// más del doble. La web es una vista previa sin cuenta de correo: ahí no se
/// justifica trabar la pestaña un segundo en cada ingreso.
const int kVueltasClaveWeb = 20000;

const int _largoSal = 16;
const int _largoHuella = 32;

/// Una contraseña convertida en huella, con lo necesario para volver a
/// comprobarla.
class HuellaClave {
  const HuellaClave({
    required this.huella,
    required this.sal,
    required this.vueltas,
  });

  /// Saca la huella de una contraseña con sal nueva.
  ///
  /// La sal es aleatoria para cada huella: dos personas con la misma contraseña
  /// —o la misma persona en dos teléfonos— no dejan la misma huella.
  factory HuellaClave.de(String clave, {int vueltas = kVueltasClave}) {
    final aleatorio = Random.secure();
    final sal = Uint8List.fromList(
      List.generate(_largoSal, (_) => aleatorio.nextInt(256)),
    );

    return HuellaClave(
      huella: base64Encode(
        pbkdf2Sha256(utf8.encode(clave), sal, vueltas, _largoHuella),
      ),
      sal: base64Encode(sal),
      vueltas: vueltas,
    );
  }

  /// En base64, para guardarlas como texto.
  final String huella;
  final String sal;
  final int vueltas;

  /// ¿Esta contraseña deja la misma huella?
  ///
  /// Nunca lanza: una huella dañada en la base es una contraseña que no
  /// coincide, no una app que se cae en el login.
  bool coincide(String clave) {
    try {
      final esperada = base64Decode(huella);
      final obtenida = pbkdf2Sha256(
        utf8.encode(clave),
        base64Decode(sal),
        vueltas,
        esperada.length,
      );
      return igualesEnTiempoConstante(esperada, obtenida);
    } catch (_) {
      return false;
    }
  }
}

/// PBKDF2-HMAC-SHA256 (RFC 8018).
///
/// `crypto` trae el HMAC pero no PBKDF2, y sumar un paquete de criptografía
/// entero por veinte líneas no vale la pena. Está probado contra los vectores
/// publicados.
Uint8List pbkdf2Sha256(
  List<int> clave,
  List<int> sal,
  int vueltas,
  int largo,
) {
  if (vueltas < 1) throw ArgumentError.value(vueltas, 'vueltas');
  if (largo < 1) throw ArgumentError.value(largo, 'largo');

  final hmac = Hmac(sha256, clave);
  final salida = BytesBuilder(copy: false);

  for (var bloque = 1; salida.length < largo; bloque++) {
    final entrada = Uint8List(sal.length + 4)..setAll(0, sal);
    ByteData.sublistView(entrada).setUint32(sal.length, bloque);

    var u = hmac.convert(entrada).bytes;
    final t = Uint8List.fromList(u);

    for (var i = 1; i < vueltas; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }

    salida.add(t);
  }

  return Uint8List.sublistView(salida.takeBytes(), 0, largo);
}

/// Compara sin cortar en la primera diferencia: el tiempo que tarda no dice
/// cuántos bytes acertó quien está probando.
bool igualesEnTiempoConstante(List<int> a, List<int> b) {
  if (a.length != b.length) return false;

  var diferencia = 0;
  for (var i = 0; i < a.length; i++) {
    diferencia |= a[i] ^ b[i];
  }
  return diferencia == 0;
}
