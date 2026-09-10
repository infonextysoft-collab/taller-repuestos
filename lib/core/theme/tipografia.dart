import 'package:flutter/material.dart';

import 'tokens.dart';

/// La familia de la app: **Archivo**, en su versión variable.
///
/// Es una grotesca con dos ejes —peso (`wght`) y ancho (`wdth`)— y ese segundo
/// eje es la razón de haberla elegido: permite que los importes salgan
/// **angostos y pesados**, que es la forma que tiene un marcador deportivo, sin
/// meter una segunda fuente en la app.
///
/// Se usa una sola familia para todo. Mezclar una fuente de titulares con otra
/// de texto es lo que hace que una interfaz se vea armada con piezas sueltas;
/// acá la variación la dan los ejes, no otro archivo.
const String familia = 'Archivo';

/// Instancia del eje variable. Cuanto más chico el ancho, más "marcador".
List<FontVariation> _ejes(double peso, [double ancho = 100]) => [
      FontVariation('wght', peso),
      FontVariation('wdth', ancho),
    ];

/// La escala tipográfica.
///
/// La jerarquía se arma con **tamaño + peso + ancho + interlineado + tracking
/// como conjunto**, no subiendo el tamaño y ya. Tres reglas que se aplican en
/// toda la escala:
///
///   - El **tracking** va al revés del tamaño: negativo en lo grande (a más
///     tamaño, las letras se ven demasiado separadas) y ligeramente positivo
///     en lo chico (para que no se apelmace).
///   - El **interlineado** también va al revés: ajustado en títulos —son pocas
///     palabras—, suelto en texto de lectura.
///   - El **ancho** se cierra a medida que el tamaño crece. Un título en ancho
///     normal ocupa dos renglones donde uno angosto entra en uno, y de paso
///     gana tensión.
class Tipo {
  const Tipo._();

  /// La bienvenida y los números que tienen que gritar.
  static final TextStyle display = TextStyle(
    fontFamily: familia,
    fontSize: 40,
    fontVariations: _ejes(800, 88),
    letterSpacing: -1.4,
    height: 0.98,
    color: Tono.texto,
  );

  /// Título de pantalla.
  static final TextStyle titulo1 = TextStyle(
    fontFamily: familia,
    fontSize: 27,
    fontVariations: _ejes(780, 92),
    letterSpacing: -0.6,
    height: 1.1,
    color: Tono.texto,
  );

  /// Título de sección grande.
  static final TextStyle titulo2 = TextStyle(
    fontFamily: familia,
    fontSize: 20,
    fontVariations: _ejes(720, 96),
    letterSpacing: -0.3,
    height: 1.2,
    color: Tono.texto,
  );

  /// Encabezado de una fila o de un bloque.
  static final TextStyle encabezado = TextStyle(
    fontFamily: familia,
    fontSize: 16,
    fontVariations: _ejes(680),
    letterSpacing: -0.1,
    height: 1.25,
    color: Tono.texto,
  );

  /// Texto de lectura.
  static final TextStyle cuerpo = TextStyle(
    fontFamily: familia,
    fontSize: 15,
    fontVariations: _ejes(400),
    height: 1.45,
    color: Tono.texto,
  );

  /// Texto secundario, el que acompaña.
  static final TextStyle secundario = TextStyle(
    fontFamily: familia,
    fontSize: 13.5,
    fontVariations: _ejes(450),
    letterSpacing: 0.05,
    height: 1.4,
    color: Tono.texto2,
  );

  /// Metadata: fechas, contadores, aclaraciones.
  static final TextStyle nota = TextStyle(
    fontFamily: familia,
    fontSize: 12,
    fontVariations: _ejes(520),
    letterSpacing: 0.15,
    height: 1.35,
    color: Tono.texto2,
  );

  /// Etiqueta de sección. Se usa **poco**: si cada campo lleva una etiqueta en
  /// mayúsculas, ninguna resalta y no hay jerarquía, solo ruido.
  static final TextStyle etiqueta = TextStyle(
    fontFamily: familia,
    fontSize: 11,
    fontVariations: _ejes(750),
    letterSpacing: 1.2,
    height: 1.3,
    color: Tono.texto2,
  );

  /// Lo que va dentro de un botón.
  static final TextStyle boton = TextStyle(
    fontFamily: familia,
    fontSize: 15.5,
    fontVariations: _ejes(780, 96),
    letterSpacing: 0.2,
    height: 1.2,
    color: Tono.textoInverso,
  );

  /* --------------------------------------------------------------- plata */

  /// El marcador: el número más grande de una pantalla.
  ///
  /// Angosto (`wdth 84`) y pesado (`wght 800`). Esa combinación es la que hace
  /// que una cifra se lea como un resultado y no como un dato más del
  /// formulario.
  static final TextStyle marcador = TextStyle(
    fontFamily: familia,
    fontSize: 46,
    fontVariations: _ejes(800, 84),
    letterSpacing: -1.8,
    height: 0.92,
    fontFeatures: kNumerosTabulares,
    color: Tono.textoInverso,
  );

  /// El importe protagonista de un bloque: el total de una boleta.
  static final TextStyle montoGrande = TextStyle(
    fontFamily: familia,
    fontSize: 32,
    fontVariations: _ejes(790, 88),
    letterSpacing: -1.1,
    height: 1,
    fontFeatures: kNumerosTabulares,
    color: Tono.vino,
  );

  /// El importe de una fila.
  static final TextStyle monto = TextStyle(
    fontFamily: familia,
    fontSize: 16.5,
    fontVariations: _ejes(760, 92),
    letterSpacing: -0.2,
    height: 1.2,
    fontFeatures: kNumerosTabulares,
    color: Tono.texto,
  );

  /// Importe secundario: un subtotal, un precio unitario.
  static final TextStyle montoChico = TextStyle(
    fontFamily: familia,
    fontSize: 13.5,
    fontVariations: _ejes(620),
    height: 1.3,
    fontFeatures: kNumerosTabulares,
    color: Tono.texto2,
  );
}
