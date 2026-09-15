# MS — trabajos, repuestos y documentos

App para un técnico electricista/mecánico independiente. Registra cada trabajo o
venta de repuestos y genera dos papeles: un **Reporte de servicio** y una
**Boleta** (o dos boletas separadas). Además lleva inventario y recordatorios de
mantenimiento.

Tres reglas de producto que mandan sobre todo lo demás:

1. **Funciona sin internet.** No hay servidor ni sincronización: todos los
   datos viven en el dispositivo. Lo único que usa la red es la recuperación de
   contraseña por correo, y es opcional.
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
es ceremonia — cuando llegó la cuenta de correo se tocó `data/` y ninguna
pantalla de negocio se enteró.

```
lib/
├── core/            transversal: tokens de diseño, movimiento, utilidades
│   ├── theme/       colores, espacios, curvas de animación
│   ├── utils/       funciones puras (totales, fechas, DNI/RUC, letras, huellas)
│   └── widgets/     piezas visuales sin dependencias de negocio
├── domain/          el negocio, sin saber de Flutter ni de SQLite
│   ├── entities/    Trabajo, Repuesto, Recordatorio, Negocio, líneas
│   ├── repositories/ contratos (interfaces abstractas)
│   └── services/    CalculadoraTotales — las reglas de plata
├── data/            implementación
│   ├── local/       esquema, índices y migraciones de SQLite
│   ├── repositories/ un repo por tabla
│   ├── cuenta/      la cuenta de correo (Firebase), detrás de un contrato
│   ├── documentos/  generación de los PDF
│   └── fotos/       cámara, galería y compresión
├── presentation/
│   ├── comunes/     lo que comparten varias pantallas
│   └── features/    una carpeta por sección, autocontenida
└── app/             cableado (providers), tema y raíz de la app
```

`app/providers.dart` es el **único** archivo que conoce las dos capas a la vez:
ahí se decide qué implementación concreta cumple cada contrato. Y
`data/cuenta/cuenta_firebase.dart` es el único que importa Firebase.

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
- **La sesión dura el día.** Se guarda la fecha en que se entró y al cambiar el
  día deja de valer, así que se pide la contraseña una vez por jornada. Se
  revisa al volver del segundo plano y no con un cronómetro: un cronómetro te
  echa a media tarde, con el equipo abierto y las manos sucias.
- **La contraseña se guarda como huella, nunca tal cual** (PBKDF2-SHA256, con
  sal). La de fábrica es la única sin huella: está escrita más abajo, no es un
  secreto, y "sin huella" es justamente como se sabe que nadie la cambió.
- **El correo recupera la contraseña; no decide quién entra.** Sin señal lo
  único que hay para comparar es la huella del teléfono, así que la cuenta de
  correo no puede dejar afuera a quien tiene la última contraseña con la que
  entró: no ganaría seguridad —en modo avión esa contraseña entraría igual— y
  sí podría encerrar al dueño fuera de sus propios datos. La consecuencia que
  conviene saber: **cambiar la contraseña con el enlace del correo no la
  cambia en un teléfono que sigue sin señal**, hasta que se entra con señal.
  Para cambiarla en el teléfono mismo: Negocio › Cambiar contraseña.
- **Las migraciones de la base miran antes de tocar.** Hasta la versión 4 del
  esquema, el teléfono abría la base sin migrar, así que hay bases que dicen
  "versión 1" y ya traen casi todo adentro. Cada paso se fija si la columna o
  la tabla ya existe, y hay tests que abren copias fieles de esas bases.
- **Las fotos viven en su propia tabla, con los bytes crudos.** Antes iban
  dentro del registro convertidas a texto (base64), un formato que infla
  cualquier archivo un 33%. Además el historial ya no las carga: pide solo una
  versión chica de ~8 KB, en vez de traer el JPEG completo de cada registro
  para dibujar una fila de 50 píxeles.
- **Los recordatorios se repiten con un intervalo libre** (N días, semanas,
  meses o años) y la cuenta se hace **en la unidad elegida**: "cada 3 meses"
  desde un 31 de enero cae el 30 de abril, no noventa días después.

Todo eso está cubierto por tests: `flutter test`.

## El respaldo

La app guarda todo en el dispositivo, así que **si el teléfono se pierde no hay
de dónde recuperar nada**. El respaldo es lo que tapa ese agujero sin servidor,
sin cuenta y sin costo: desde el menú de arriba, "Respaldo" arma un ZIP con todo
—registros, inventario, recordatorios y fotos— y abre la hoja de compartir para
guardarlo en Drive, el correo o WhatsApp. En un teléfono nuevo se importa y
sigue como estaba.

Adentro del ZIP van `datos.json` con las filas de cada tabla y `fotos/<id>.jpg`
con las imágenes en crudo. Es ZIP y no una copia de la base porque se puede
abrir y mirar: si algo sale mal, los datos se rescatan con el explorador de
archivos y sin esta app. **La contraseña no viaja en el respaldo.**

**Restaurar reemplaza, no mezcla.** Fusionar dos historiales con correlativos
propios dejaría códigos repetidos en los documentos.

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
Negocio › Cambiar contraseña (mínimo 6 caracteres), no editando el código.

En Windows, `flutter pub get` pide **Modo de desarrollador** activado para
poder crear los symlinks de los plugins (`start ms-settings:developers`).

El **escritorio de Windows no es destino**: con Firebase en el proyecto,
compilar para Windows descarga el SDK de C++ de Firebase. Se usa el celular, o
Chrome para mirar.

### El APK

```bash
flutter build apk --release
```

Queda en `build/app/outputs/flutter-apk/app-release.apk`. En Windows,
`android/gradle.properties` apaga la compilación incremental de Kotlin: con ella
el build se cae con *Could not close incremental caches*.

### Recuperación de contraseña por correo

Usa **Firebase Authentication en el plan gratuito** (Spark), sin tarjeta. Solo
eso: ni Firestore ni Storage.

Para activarla:

1. En la consola de Firebase: Authentication › Método de acceso › activar
   **Correo electrónico/contraseña**.
2. Registrar la app Android con el id `com.example.taller_repuestos` y dejar el
   `google-services.json` en `android/app/`.

Ese archivo **no se versiona**: el repo es público. Sin él la app compila y
funciona igual, solo que sin recuperación por correo — es lo que permite
compilar a cualquiera que clone el proyecto. En la vista web tampoco está.

Si algún día cambia el `applicationId` (Play Store no acepta `com.example`),
hay que registrar la app de nuevo en Firebase y bajar otro json: con el viejo,
el build falla.

Dentro de la app: Negocio › Recuperación por correo. Con la contraseña de
fábrica no deja vincular: una cuenta con esa contraseña sería de cualquiera.

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

- **Respaldo automático en la nube.** Hoy el respaldo es manual, y depende de
  que alguien se acuerde de hacerlo. La cuenta de correo ya existe, pero
  **Cloud Storage exige plan Blaze** (con tarjeta), así que la subida
  automática de las fotos quedó pendiente de esa decisión.
- **Confirmar el correo desde la app.** Al vincularlo se manda un correo de
  confirmación; si no llega, es la señal de que la dirección quedó mal escrita.
  La app todavía no muestra si ya se confirmó.
- **La clave de firma del APK.** Hoy va firmado con la de depuración: sirve
  para instalarlo, no para Play Store.
- Notificaciones push reales — hoy el aviso de vencidos sale al abrir la app.
