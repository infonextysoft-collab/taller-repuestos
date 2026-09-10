# MS — trabajos, repuestos y documentos

App para un técnico electricista/mecánico independiente. Registra cada trabajo o
venta de repuestos y genera dos papeles: un **Reporte de servicio** y una
**Boleta** (o dos boletas separadas). Además lleva inventario y recordatorios de
mantenimiento.

Tres reglas de producto que mandan sobre todo lo demás:

1. **Funciona 100% sin internet.** No hay servidor ni sincronización: todos los
   datos viven en el dispositivo.
2. **No es facturación electrónica SUNAT.** Es documentación interna; el
   contador la presenta a fin de mes.
3. **Se usa con una mano, parado en un taller o en el campo.** Área táctil
   mínima 44px y nada de formularios largos sin poder guardar a medias.

## Arquitectura

```
Widget → Controlador → Repositorio (contrato) → SQLite
         presentation/   domain/                 data/
```

Cada capa habla **solo** con la de al lado, y siempre hacia adentro: la
presentación conoce los contratos de `domain/`, nunca la implementación. Esto no
es ceremonia — el día que se agregue backup en la nube se toca `data/` y nada
más se entera.

```
lib/
├── core/            transversal: tokens de diseño, movimiento, utilidades
│   ├── theme/       colores, espacios, curvas de animación
│   ├── utils/       funciones puras (totales, fechas, DNI/RUC, letras)
│   └── widgets/     piezas visuales sin dependencias de negocio
├── domain/          el negocio, sin saber de Flutter ni de SQLite
│   ├── entities/    Trabajo, Repuesto, Recordatorio, Negocio, líneas
│   ├── repositories/ contratos (interfaces abstractas)
│   └── services/    CalculadoraTotales — las reglas de plata
├── data/            implementación
│   ├── local/       esquema e índices de SQLite
│   ├── repositories/ un repo por tabla
│   ├── documentos/  generación de los PDF
│   └── fotos/       cámara, galería y compresión
├── presentation/
│   ├── comunes/     lo que comparten varias pantallas
│   └── features/    una carpeta por sección, autocontenida
└── app/             cableado (providers), tema y raíz de la app
```

`app/providers.dart` es el **único** archivo que conoce las dos capas a la vez:
ahí se decide qué implementación concreta cumple cada contrato.

## Las reglas que no se negocian

- **El IGV (18%) ya está incluido en los precios.** No se suma encima: se
  desagrega del total solo para mostrarlo. El cliente paga la suma de las líneas
  menos el descuento, ni un sol más.
- **El traslado se cobra solo en campo Y con movilidad propia.** Las dos
  condiciones, siempre.
- **Dos boletas separadas suman exactamente lo mismo que la junta**, total e
  IGV. Por eso el descuento y el impuesto de la segunda salen por diferencia.
- **La mano de obra no lleva cantidad**: un trabajo se cobra por lo acordado.
- **El stock se mueve al agregar y al quitar cada línea**, no al guardar el
  registro; salir sin guardar restaura el inventario al estado que tenía.
- **Las fechas son ISO corto sin hora ni zona horaria.** Hoy todavía no está
  vencido.
- **Los recordatorios se repiten con un intervalo libre** (N días, semanas,
  meses o años) y la cuenta se hace **en la unidad elegida**: "cada 3 meses"
  desde un 31 de enero cae el 30 de abril, no noventa días después.

Todo eso está cubierto por tests: `flutter test`.

## La tarjeta de arriba del Historial

No muestra plata. Es un técnico solo, no un tablero de negocio: "cuánto registré
desde siempre" es un número que solo crece y no contesta nada. Muestra **lo que
hay que atender**, en tarjetas que se deslizan:

1. **Hoy toca** — mantenimientos vencidos y los de hoy. Lleva a Avisos.
2. **Sin cerrar** — registros a medias, trabajo hecho sin papel. Filtra la lista.
3. **Sin stock** — repuestos agotados. Lleva al inventario ya filtrado.

Dos reglas: **las vacías no se muestran** y se ordenan por urgencia, así la
primera nunca es un cero; y **cuando hay uno solo, el titular es el nombre**
—"Juan Ramírez", no "1 vence hoy"—, porque lo que se hace con ese dato es
levantar el teléfono.

Los chips de abajo filtran **solo la lista**, no la tarjeta: son dos preguntas
distintas y mezclarlas hacía que el resumen cambiara de significado al tocar un
filtro.

## Cómo se ve

La tipografía es **Archivo variable**, un solo archivo en `assets/fonts/`. Se
eligió por su eje de ancho (`wdth`): permite que los importes salgan angostos y
pesados, que es la forma de un marcador, sin sumar una segunda fuente. Los ejes
se piden desde `Tipo` con `FontVariation`; nadie escribe un `fontWeight` suelto.

La paleta son dos colores de marca —vino `#761C1C` y oro `#87611A`— sobre
neutros cálidos, más el **negro como superficie** (no como color de marca): es
lo que le da peso al marcador y a la barra de navegación sin meter un tercer
tono.

### Mirar las pantallas sin abrir la app

`flutter analyze` y los tests de dominio no dicen **nada** sobre si la interfaz
se ve bien: ya pasó una vez que todo compilaba y la pantalla salía en blanco.
Por eso hay retratos de las pantallas, que se dibujan de verdad —con la fuente y
los íconos cargados— y quedan como PNG en `test/capturas/`:

```bash
flutter test test/capturas_test.dart --run-skipped --update-goldens
```

No corren en la suite normal: son imágenes y dependen de la máquina que las
generó, así que fallarían en cualquier otro equipo por diferencias de un píxel.

## Correr el proyecto

En el celular, que es donde se usa:

```bash
flutter pub get
flutter run
```

Primer ingreso: usuario `Samuel`, contraseña `Admin123`. Se cambia desde
Negocio › Cambiar contraseña, no editando el código.

En Windows, `flutter pub get` pide **Modo de desarrollador** activado para
poder crear los symlinks de los plugins (`start ms-settings:developers`).

### En el navegador, para mirar rápido

La app también corre en Chrome. Es una vista previa de desarrollo, no el
destino: **las fotos y el escáner necesitan el celular**, y los datos del
navegador son otros —cada dispositivo tiene su propia base—.

Hace falta una vez, para dejar el SQLite compilado a WebAssembly en `web/`:

```bash
dart run sqflite_common_ffi_web:setup
```

Y después:

```bash
flutter build web
python .dev/servir.py 5599
```

Se sirve con ese script y no con `python -m http.server` porque el módulo
estándar no conoce `.wasm`: lo entrega con el tipo equivocado, el navegador lo
rechaza y SQLite nunca arranca.

## Pendiente, fuera de alcance por ahora

- Backup en la nube.
- **El APK de Android nunca se llegó a compilar hasta el final**: el build se
  cortó a los 40 minutos. La app corre en el navegador y las pantallas están
  verificadas con los retratos, pero el paquete de Android está sin probar.
- Notificaciones push reales — hoy el aviso de vencidos sale al abrir la app.
