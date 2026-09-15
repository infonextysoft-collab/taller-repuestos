import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/core/utils/clave_segura.dart';

/// La huella de la contraseña.
///
/// Un PBKDF2 escrito a mano que da un resultado "parecido" es un PBKDF2 roto
/// que igual deja entrar. Por eso se prueba contra los vectores publicados, que
/// además se recalcularon con `hashlib.pbkdf2_hmac` de Python.
void main() {
  String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  group('PBKDF2-HMAC-SHA256 contra los vectores conocidos', () {
    test('1 vuelta', () {
      expect(
        hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('2 vueltas', () {
      expect(
        hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('4096 vueltas', () {
      expect(
        hex(pbkdf2Sha256(
            utf8.encode('password'), utf8.encode('salt'), 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('una salida más larga que un bloque usa el segundo bloque', () {
      // 40 bytes no entran en los 32 de un SHA-256: si el contador de bloque
      // estuviera mal, los últimos 8 bytes saldrían distintos.
      expect(
        hex(pbkdf2Sha256(
          utf8.encode('passwordPASSWORDpassword'),
          utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
          4096,
          40,
        )),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347e'
        'bc1800181c4e2a1fb8dd53e1c635518c7dac47e9',
      );
    });

    test('las tildes y la ñ se cuentan en UTF-8', () {
      expect(
        hex(pbkdf2Sha256(
          utf8.encode('Contraseña'),
          utf8.encode('sal-de-prueba'),
          10000,
          32,
        )),
        '19874e8d0b0206733801a8b2776a0a384e405ea792959aa17ccfe2f126155ea4',
      );
    });
  });

  group('HuellaClave', () {
    // Pocas vueltas: lo que se prueba acá es la lógica, no el costo.
    const vueltas = 1000;

    test('la misma contraseña coincide y otra no', () {
      final huella = HuellaClave.de('Taller2026', vueltas: vueltas);

      expect(huella.coincide('Taller2026'), isTrue);
      expect(huella.coincide('taller2026'), isFalse);
      expect(huella.coincide(''), isFalse);
    });

    test('dos huellas de la misma contraseña no son iguales', () {
      final a = HuellaClave.de('Taller2026', vueltas: vueltas);
      final b = HuellaClave.de('Taller2026', vueltas: vueltas);

      // La sal es nueva cada vez: la huella no delata contraseñas repetidas.
      expect(a.sal, isNot(b.sal));
      expect(a.huella, isNot(b.huella));
      expect(b.coincide('Taller2026'), isTrue);
    });

    test('guardada y leída de vuelta sigue sirviendo', () {
      final original = HuellaClave.de('Taller2026', vueltas: vueltas);
      final leida = HuellaClave(
        huella: original.huella,
        sal: original.sal,
        vueltas: original.vueltas,
      );

      expect(leida.coincide('Taller2026'), isTrue);
    });

    test('una huella dañada no coincide y no revienta', () {
      const rota = HuellaClave(huella: 'no-es-base64!!', sal: '###', vueltas: 1);
      expect(rota.coincide('lo que sea'), isFalse);

      const sinVueltas = HuellaClave(huella: 'AAAA', sal: 'AAAA', vueltas: 0);
      expect(sinVueltas.coincide('lo que sea'), isFalse);
    });

    test('las vueltas por defecto son las del estándar del proyecto', () {
      expect(HuellaClave.de('x').vueltas, kVueltasClave);
    });
  });

  test('la comparación exige mismo largo y mismos bytes', () {
    expect(igualesEnTiempoConstante([1, 2, 3], [1, 2, 3]), isTrue);
    expect(igualesEnTiempoConstante([1, 2, 3], [1, 2, 4]), isFalse);
    expect(igualesEnTiempoConstante([1, 2, 3], [1, 2]), isFalse);
  });
}
