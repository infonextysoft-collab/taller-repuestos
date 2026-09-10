import 'package:flutter/material.dart';

/// Los tokens de diseño de la app. Nadie escribe un color ni un margen a mano:
/// todo sale de acá, así el día que cambie la marca cambia un archivo.
///
/// La paleta son **dos colores de marca sobre neutros cálidos**, más el negro
/// como superficie:
///
///   - **vino** `#761C1C` — la acción y el peso. Lo que se toca para avanzar,
///     el total, y también lo que hay que mirar dos veces (vencido, agotado).
///     Nunca dos veces con el mismo tratamiento: lleno es acción, suave es
///     alerta.
///   - **oro** `#87611A` — el acento y lo que está bien. Stock disponible,
///     cumplido, un dato que acompaña. Sobre superficies oscuras sube a
///     [oroClaro], que es donde de verdad rinde.
///   - **negro** `#12110F` — no es un color de marca, es una superficie. Es lo
///     que le da peso a la app sin meter un tercer tono: el marcador, la barra
///     flotante, las cabeceras que tienen que pesar.
///
/// Con dos colores, la diferencia entre "hacé esto" y "ojo con esto" no la da
/// el tono: la da el **relleno**. Lleno = acción, suave = estado.
class Tono {
  const Tono._();

  /* ------------------------------------------------------------ marca */

  /// Relleno de botones y color de marca.
  static const Color vino = Color(0xFF761C1C);

  /// Más oscuro, para bandas y degradados donde el vino plano se aplana.
  static const Color vinoHondo = Color(0xFF4E1212);

  /// Casi negro con temperatura de vino: el fondo del marcador.
  static const Color vinoNoche = Color(0xFF2A0E0E);

  /// El mismo vino ya contrasta 10:1 sobre blanco, así que el texto no
  /// necesita una variante aparte — pero el nombre deja claro, donde se lee,
  /// que ahí va texto y no un relleno.
  static const Color vinoTexto = Color(0xFF761C1C);
  static const Color vinoSuave = Color(0xFFFBF0EF);
  static const Color vinoBorde = Color(0xFFE7C8C5);

  /// Acento. Sobre blanco contrasta 5.5:1: alcanza para texto.
  static const Color oro = Color(0xFF87611A);

  /// Para texto y trazos sobre superficies oscuras: el oro normal se apaga
  /// contra el vino y contra el negro.
  static const Color oroClaro = Color(0xFFD9AE52);

  /// El oro al máximo, para un trazo fino que tiene que cortar: la línea de
  /// velocidad, el subrayado de la pestaña activa sobre negro.
  static const Color oroVivo = Color(0xFFF2C765);

  static const Color oroTexto = Color(0xFF87611A);
  static const Color oroSuave = Color(0xFFFBF5E8);
  static const Color oroBorde = Color(0xFFE4D2A9);

  /* -------------------------------------------------------- superficies */

  /// La superficie con peso. Cálido, nunca `#000000`: el negro puro sobre una
  /// pantalla OLED corta con el resto de la app y se ve como un agujero.
  static const Color negro = Color(0xFF12110F);

  /// Un escalón por encima del negro, para lo que flota sobre él.
  static const Color negro2 = Color(0xFF1E1C19);

  /// Separadores sobre negro. Una línea clara al 8% se ve sucia; este gris
  /// oscuro se lee como un borde real.
  static const Color negroLinea = Color(0xFF2E2A25);

  static const Color fondo = Color(0xFFFFFFFF);
  static const Color fondo2 = Color(0xFFF4F2EF);
  static const Color linea = Color(0xFFE7E4DF);
  static const Color lineaFuerte = Color(0xFFD6D2CB);

  /* -------------------------------------------------------------- texto */

  /// Gris con matiz cálido, nunca negro puro.
  static const Color texto = Color(0xFF14130F);

  /// Secundario. Contrasta 7.3:1 sobre blanco.
  static const Color texto2 = Color(0xFF5A554C);

  /// Terciario: fechas, contadores, aclaraciones.
  ///
  /// Está en `#7B746A` y **no** más claro por una razón concreta: el gris que
  /// había antes daba 2.9:1 sobre blanco, contra el mínimo legible de 4.5:1.
  /// Se veía "transparente" en todas las pantallas. Este da 4.6:1. Si hace
  /// falta que algo pese menos, se baja el tamaño o el peso — no el contraste.
  static const Color texto3 = Color(0xFF7B746A);

  /// Texto sobre superficies llenas de marca o sobre negro.
  static const Color textoInverso = Color(0xFFFDF9F7);

  /// El secundario sobre oscuro. Es un color **sólido**, no blanco con alfa:
  /// el blanco translúcido se lee como texto a medio cargar.
  static const Color textoInverso2 = Color(0xFFC9BEBB);

  /// Deshabilitado. Se ve apagado pero **se lee** (4.7:1 sobre su fondo): un
  /// botón que no se puede tocar todavía tiene que decir qué botón es.
  static const Color apagadoFondo = Color(0xFFEDEAE4);
  static const Color apagadoTexto = Color(0xFF6B6862);
}

/// Grilla de 8px. Los cuatro primeros valores cubren casi todo.
class Espacio {
  const Espacio._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Se llama `Redondeo` y no `Radio` porque `Radio` ya es un widget de Material.
class Redondeo {
  const Redondeo._();

  static const double chico = 12;
  static const double normal = 18;
  static const double grande = 26;

  static const BorderRadius brChico = BorderRadius.all(Radius.circular(chico));
  static const BorderRadius brNormal = BorderRadius.all(Radius.circular(normal));
  static const BorderRadius brGrande = BorderRadius.all(Radius.circular(grande));
}

/// Sombras sobre el gris cálido del texto, no sobre negro: sobre un fondo
/// hueso una sombra negra se ve sucia.
///
/// Se usan **solo en lo que de verdad flota** —la hoja, el botón de agregar,
/// la barra inferior—. Poner borde fino + sombra difusa en cada tarjeta no
/// comunica jerarquía: solo hace que todo pese lo mismo.
class Sombra {
  const Sombra._();

  static const List<BoxShadow> baja = [
    BoxShadow(color: Color(0x0D14130F), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> media = [
    BoxShadow(color: Color(0x1414130F), blurRadius: 20, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> alta = [
    BoxShadow(color: Color(0x2314130F), blurRadius: 36, offset: Offset(0, 14)),
  ];
}

/// Se usa con una mano, parado en un taller. 44px es el mínimo que se acierta
/// sin mirar.
const double kAreaTactil = 44;

/// Números de plata: **tabulares**, para que las columnas de importes queden
/// alineadas dígito con dígito y un total no baile al cambiar de cifra.
const List<FontFeature> kNumerosTabulares = [FontFeature.tabularFigures()];

/// La inclinación de los cortes en diagonal, en píxeles de corrimiento.
///
/// Todas las diagonales de la app usan **la misma**: dos ángulos distintos en
/// una pantalla se leen como un error de alineación, no como una decisión.
const double kInclinacion = 22;

/// Anchos de contenido. La app corre en celular, tablet y escritorio.
class Ancho {
  const Ancho._();

  static const double compacto = 460;
  static const double medio = 760;
  static const double amplio = 1000;

  /// Columna de lectura: más ancho que esto y el ojo pierde el renglón.
  static const double lectura = 620;

  /// Bloques de acciones (formularios, botoneras).
  static const double acciones = 460;
}
