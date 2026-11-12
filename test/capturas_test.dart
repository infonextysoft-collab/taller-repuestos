@Tags(['capturas'])
library;

import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_repuestos/app/providers.dart';
import 'package:taller_repuestos/core/utils/clave_segura.dart';
import 'package:taller_repuestos/core/utils/fechas.dart';
import 'package:taller_repuestos/core/theme/app_theme.dart';
import 'package:taller_repuestos/core/theme/tokens.dart';
import 'package:taller_repuestos/data/local/app_database.dart';
import 'package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/negocio_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/recordatorios_repository_sqlite.dart';
import 'package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart';
import 'package:taller_repuestos/domain/entities/linea.dart';
import 'package:taller_repuestos/domain/entities/negocio.dart';
import 'package:taller_repuestos/domain/entities/recordatorio.dart';
import 'package:taller_repuestos/domain/entities/repeticion.dart';
import 'package:taller_repuestos/domain/entities/repuesto.dart';
import 'package:taller_repuestos/domain/entities/trabajo.dart';
import 'package:taller_repuestos/domain/services/calculadora_totales.dart';
import 'package:taller_repuestos/presentation/comunes/elegir_documentos.dart';
import 'package:taller_repuestos/presentation/features/apertura/pantalla_apertura.dart';
import 'package:taller_repuestos/presentation/features/auth/pantalla_login.dart';
import 'package:taller_repuestos/presentation/features/inventario/formulario_repuesto.dart';
import 'package:taller_repuestos/presentation/features/inventario/pantalla_actualizar_stock.dart';
import 'package:taller_repuestos/presentation/features/reportes/pantalla_reportes.dart';
import 'package:taller_repuestos/presentation/features/negocio/pantalla_negocio.dart';
import 'package:taller_repuestos/presentation/features/negocio/pantalla_respaldo.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/pantalla_completados.dart';
import 'package:taller_repuestos/presentation/features/recordatorios/pantalla_programados.dart';
import 'package:taller_repuestos/presentation/features/shell/shell_principal.dart';
import 'package:taller_repuestos/presentation/features/trabajo/wizard_trabajo.dart';

import 'falsos/cuenta_falsa.dart';

/// Retratos de las pantallas, para mirarlas.
///
/// Existe porque `flutter analyze` y los tests de dominio **no dicen nada**
/// sobre si la app se ve bien: ya pasó una vez que todo compilaba y la pantalla
/// salía en blanco. Esto dibuja las pantallas de verdad, con la fuente y los
/// íconos cargados, y deja los PNG en `test/capturas/`.
///
/// Va con la etiqueta `capturas` para que no corra en la suite normal —los
/// PNG dependen del equipo que los generó—:
///
/// ```
/// flutter test test/capturas_test.dart --run-skipped --update-goldens
/// ```
void main() {
  late AppDatabase base;

  setUpAll(_cargarFuentes);

  setUp(() async {
    // El acceso lee preferencias (la sesión, el freno de intentos) y en las
    // pruebas no hay plugin del otro lado.
    SharedPreferences.setMockInitialValues({});
    base = await AppDatabase.enMemoria();
    await _sembrar(base);
  });

  // Se cierra con un respiro: la pantalla deja consultas en vuelo y cerrar la
  // base debajo las hace fallar. Y hay que cerrarla, o la base en memoria es
  // la misma para la captura siguiente y los datos se acumulan.
  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await base.cerrar();
  });

  testWidgets('bienvenida a mitad de la soldadura', (tester) async {
    // Sin `runAsync`: se pumpean cuadros con el reloj falso para congelar la
    // animación en el medio. Con el reloj real, la portada ya se habría ido.
    await _montar(tester, PantallaApertura(alTerminar: (_) {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 620));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/0-bienvenida.png'),
    );

    // La portada deja programado el tope de seguridad: hay que dejarlo
    // disparar o el test termina con un temporizador vivo.
    await tester.pump(PantallaApertura.maximo);
    await tester.pump(PantallaApertura.porton);
    await tester.pumpAndSettle();
  });

  testWidgets('login', (tester) async {
    await _mostrar(tester, PantallaLogin(alEntrar: () {}));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/7-login.png'),
    );
  });

  testWidgets('login con correo vinculado', (tester) async {
    await tester.runAsync(
      () => _ponerClave('Taller2026', correo: 'wilmer.taller@gmail.com'),
    );
    await _mostrar(tester, PantallaLogin(alEntrar: () {}));
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/14-login-correo.png'),
    );
  });

  testWidgets('login: la cuenta ya no acepta la contraseña', (tester) async {
    await tester.runAsync(
      () => _ponerClave('Taller2026', correo: 'wilmer.taller@gmail.com'),
    );
    // Se cambió con el enlace del correo en otra parte: la cuenta tiene otra.
    nube_.cuentas['wilmer.taller@gmail.com'] = 'LaCambioOtro';

    await _mostrar(tester, PantallaLogin(alEntrar: () {}));
    await tester.enterText(find.byType(TextFormField).last, 'Taller2026');
    await tester.tap(find.text('Entrar'));
    await _esperarA(tester, find.text('Seguir sin el correo'));
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/15-login-rechazo.png'),
    );
  });

  testWidgets('ventana de recuperación por correo', (tester) async {
    await tester.runAsync(() => _ponerClave('Taller2026'));
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.storefront_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recuperación por correo'));
    await _asentar(tester);
    expect(find.text('Vincular correo'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/16-ventana-correo.png'),
    );
  });

  testWidgets('ventana de correo con la contraseña de fábrica', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.storefront_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recuperación por correo'));
    await _asentar(tester);
    expect(find.textContaining('contraseña de fábrica'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/17-ventana-correo-fabrica.png'),
    );
  });

  testWidgets('historial', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/1-historial.png'),
    );
  });

  testWidgets('ventana de nuevo registro', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/8-ventana.png'),
    );
  });

  testWidgets('tarjeta deslizada: sin stock', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));

    // Dos arrastres para llegar a la tercera tarjeta.
    for (var i = 0; i < 2; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/11-tarjeta-stock.png'),
    );
  });

  testWidgets('ventana de acciones de un registro', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await _asentar(tester);
    expect(find.text('Descargar PDF'), findsOneWidget);
    expect(find.byTooltip('Compartir'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/10-ventana-acciones.png'),
    );
  });

  testWidgets('ventana con campos: cambiar contraseña', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.storefront_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña').last);
    await _asentar(tester);
    // Un ojo por cada campo de contraseña.
    expect(find.byTooltip('Mostrar contraseña'), findsNWidgets(3));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/9-ventana-clave.png'),
    );
  });

  testWidgets('wizard paso 1', (tester) async {
    await _mostrar(tester, const WizardTrabajo());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/2-wizard.png'),
    );
  });

  testWidgets('wizard paso 4, mano de obra y repuestos juntos', (tester) async {
    await _mostrar(tester, WizardTrabajo(id: pendienteId));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/6-wizard-cobro.png'),
    );
  });

  testWidgets('wizard paso 2, las dos tandas de fotos', (tester) async {
    await _mostrar(tester, WizardTrabajo(id: pendienteId));
    // Abre en el paso 4; dos pasos atrás para llegar a las fotos.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
      await _asentar(tester);
    }
    // El paso viene cerrado porque ya se guardo: se reabre para ver los
    // botones de camara y galeria.
    await tester.tap(find.text('Editar'));
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/12-wizard-fotos.png'),
    );
  });

  testWidgets('respaldo', (tester) async {
    await _mostrar(tester, const PantallaRespaldo());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/13-respaldo.png'),
    );
  });

  testWidgets('negocio', (tester) async {
    await _mostrar(tester, const PantallaNegocio());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/3-negocio.png'),
    );
  });

  testWidgets('recordatorios', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    // La tercera pestaña de la barra de abajo.
    await tester.tap(find.byIcon(Icons.notifications_rounded).first);
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/4-recordatorios.png'),
    );
  });

  testWidgets('avisos: programados', (tester) async {
    await _mostrar(tester, const PantallaProgramados());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/23-avisos-programados.png'),
    );
  });

  testWidgets('avisos: completados por mes', (tester) async {
    await _mostrar(tester, const PantallaCompletados());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/24-avisos-completados.png'),
    );
  });

  testWidgets('avisos: la ventana de un mes', (tester) async {
    await _mostrar(tester, const PantallaCompletados());
    await tester.tap(find.text('Octubre'));
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/25-avisos-mes.png'),
    );
  });

  testWidgets('avisos: el detalle y eliminar uno que se repite', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.notifications_rounded).first);
    await _asentar(tester);

    await tester.tap(find.textContaining('Cambiar filtro').first);
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/26-avisos-detalle.png'),
    );

    await tester.tap(find.text('Eliminar'));
    await _asentar(tester);
    await tester.tap(find.text('Eliminar solo este'));
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/27-avisos-eliminar.png'),
    );
  });

  testWidgets('compartir: elegir qué papeles van', (tester) async {
    const trabajo = Trabajo(
      codigo: 'REP-2026-0002',
      tipo: TipoTrabajo.taller,
      estado: EstadoTrabajo.terminado,
      fecha: '2026-09-13',
      vistaDoc: VistaDoc.separado,
      trabajosRealizados: [LineaMano(desc: 'Lavado', precio: 40)],
      repuestos: [LineaRepuesto(desc: 'Foco', cantidad: 1, precio: 50)],
    );

    await _mostrar(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => elegirDocumentos(
                context,
                trabajo,
                calculadora.calcularBoletas(trabajo),
                compartir: true,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await _asentar(tester);
    await tester.tap(find.text('Reporte de trabajo'));
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/28-compartir-casillas.png'),
    );
  });

  testWidgets('formulario de repuesto: los dos precios y lo que deja',
      (tester) async {
    final item = await tester.runAsync(
      () => InventarioRepositorySqlite(base_).porNombreExacto('Filtro de aceite'),
    );
    expect(item, isNotNull);

    await _mostrar(tester, FormularioRepuesto(repuesto: item));
    expect(find.textContaining('Ganas'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/18-repuesto.png'),
    );
  });

  testWidgets('ficha de un repuesto', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.inventory_2_rounded).first);
    await _asentar(tester);
    await tester.tap(find.text('FILTRO DE ACEITE'));
    await _esperarA(tester, find.text('Vendidos'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Se lo compras a'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/19-ficha-repuesto.png'),
    );
  });

  testWidgets('reportes', (tester) async {
    await _mostrar(tester, const PantallaReportes());
    await _esperarA(tester, find.text('LO QUE MÁS SALE'));
    // "Todo" y no "Este mes": una captura que se vacía al cambiar de mes no
    // sirve para comparar nada. Ahora se elige desde el filtro.
    await tester.tap(find.byType(OutlinedButton).first);
    await _asentar(tester);
    await tester.tap(find.text('Todo'));
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/21-reportes.png'),
    );
  });

  testWidgets('actualizar stock', (tester) async {
    await _mostrar(tester, const PantallaActualizarStock());
    await _esperarA(tester, find.text('FILTRO DE ACEITE'));
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/22-actualizar-stock.png'),
    );
  });

  testWidgets('inventario', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.inventory_2_rounded).first);
    await _asentar(tester);
    expect(find.byTooltip('Nuevo repuesto'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/5-inventario.png'),
    );
  });

  // Sin captura: solo mide. Un teléfono de 360 puntos con contadores de dos
  // cifras es el caso justo, y ahí el "+" no puede tapar "Agotados".
  testWidgets('inventario en 360 puntos: los chips entran junto al +',
      (tester) async {
    final inventario = InventarioRepositorySqlite(base_);
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await inventario.crear(
          Repuesto(nombre: 'Con stock $i', stock: 5, precio: 10),
        );
        await inventario.crear(Repuesto(nombre: 'Agotado $i', precio: 10));
      }
    });

    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    tester.view.physicalSize = const Size(1080, 2400);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.inventory_2_rounded).first);
    await _asentar(tester);

    // Todos 23 · Con stock 12 · Agotados 11.
    expect(find.text('23'), findsOneWidget);
    final chip = find.ancestor(
      of: find.text('Agotados'),
      matching: find.byType(AnimatedContainer),
    );
    final rect = tester.getRect(chip.first);
    expect(
      rect.right,
      lessThanOrEqualTo(
        tester.getRect(find.byTooltip('Nuevo repuesto')).left - Espacio.sm,
      ),
    );
    // Entra achicándose lo justo, no a costa de volverse ilegible: el chip
    // mide 38 de alto sin achicar.
    expect(rect.height, greaterThanOrEqualTo(34));
  });
}

/* --------------------------------------------------------------- andamios */

/// Sin esto el test dibuja rectángulos en vez de letras: el motor de pruebas
/// no carga las fuentes del proyecto ni la de los íconos.
Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, String ruta) async {
    final archivo = File(ruta);
    if (!archivo.existsSync()) return;

    final bytes = archivo.readAsBytesSync();
    final loader = FontLoader(familia)
      ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
  }

  await cargar('Archivo', 'assets/fonts/Archivo.ttf');
  await cargar(
    'MaterialIcons',
    r'C:\SDK\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  await _montar(tester, pantalla);
  await _asentar(tester);
}

Future<void> _montar(WidgetTester tester, Widget pantalla) async {
  tester.view
    ..physicalSize = const Size(1125, 2436)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        baseDatosProvider.overrideWithValue(base_),
        cuentaRemotaProvider.overrideWithValue(nube_),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro(),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: pantalla,
      ),
    ),
  );
}

/// Deja que la pantalla termine de cargarse.
///
/// No se usa `pumpAndSettle`: mientras los datos no llegan hay un indicador de
/// carga girando, y un giro infinito hace que `pumpAndSettle` nunca corte. Y
/// como SQLite responde por el bucle de eventos **real**, hace falta un
/// `runAsync` en el medio o las consultas no avanzan nunca.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 900)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// La base que ven las capturas. Se guarda aparte porque `_mostrar` es una
/// función suelta y necesita alcanzarla.
late AppDatabase base_;

/// La cuenta de correo de mentira que ven las capturas.
late CuentaFalsa nube_;

/// El registro a medias, para retratar el wizard en un paso del medio.
late int pendienteId;

Future<void> _sembrar(AppDatabase db) async {
  base_ = db;
  nube_ = CuentaFalsa();

  final inventario = InventarioRepositorySqlite(db);
  final trabajos = TrabajosRepositorySqlite(db, inventario);
  final recordatorios = RecordatoriosRepositorySqlite(db);
  final negocio = NegocioRepositorySqlite(db);

  await negocio.guardar(const Negocio(
    nombre: 'Servicios MS',
    ruc: '20131312955',
    direccion: 'Av. Industrial 455, Lima',
    telefono: '999888777',
    email: 'taller@correo.com',
    banco: 'BCP',
    cuenta: '191-0123456-0-12',
    cci: '00219100123456012',
    yape: '999888777',
  ));

  await inventario.crear(const Repuesto(
    nombre: 'Filtro de aceite',
    stock: 12,
    precio: 38.5,
    precioCosto: 22.35,
    proveedor: 'Repuestos Lima',
  ));
  await inventario.crear(const Repuesto(
    nombre: 'Rodamiento 6205',
    stock: 3,
    precio: 22,
    precioCosto: 13,
  ));
  await inventario.crear(const Repuesto(nombre: 'Faja A-52', precio: 45));

  Future<void> registrar({
    required TipoTrabajo tipo,
    required String cliente,
    required String equipo,
    required String fecha,
    required double mano,
    String placa = '',
    bool cerrado = true,
  }) async {
    final creado = await trabajos.crear(Trabajo(tipo: tipo, fecha: fecha));
    final lleno = await trabajos.actualizar(creado.copyWith(
      cliente: cliente,
      equipo: equipo,
      placa: placa,
      diagnostico: 'Revisión general',
      trabajosRealizados: [LineaMano(desc: 'Mantenimiento', precio: mano)],
      repuestos: const [
        LineaRepuesto(
            desc: 'Filtro de aceite',
            cantidad: 1,
            precio: 38.5,
            costo: 22.35),
      ],
    ));
    if (cerrado) {
      await trabajos.terminar(lleno.id!);
    } else {
      // Se deja con los tres primeros pasos cerrados para que al abrirlo caiga
      // en el paso 4 y se vea la fusión de mano de obra con repuestos.
      pendienteId = lleno.id!;
      await trabajos.guardarPasosHasta(lleno.id!, 3);
    }
  }

  await registrar(
    tipo: TipoTrabajo.taller,
    cliente: 'Juan Ramírez',
    equipo: 'Compresor Atlas',
    fecha: '2026-09-02',
    mano: 180,
  );
  await registrar(
    tipo: TipoTrabajo.campo,
    cliente: 'Minera Eco Pampa',
    equipo: 'Grupo electrógeno',
    fecha: '2026-09-05',
    mano: 420,
  );
  await registrar(
    tipo: TipoTrabajo.taller,
    cliente: 'Carmen Díaz',
    equipo: 'Motor trifásico',
    fecha: '2026-09-07',
    mano: 95,
  );
  await registrar(
    tipo: TipoTrabajo.venta,
    cliente: 'Ferretería Sur',
    equipo: '',
    fecha: '2026-09-08',
    mano: 0,
  );
  await registrar(
    tipo: TipoTrabajo.taller,
    cliente: 'Luis Paredes',
    equipo: 'Bomba de agua',
    fecha: '2026-09-09',
    mano: 260,
    cerrado: false,
  );

  // Empresas a las que ya se facturó, para que el paso 1 las sugiera.
  await db.db.update(
    'trabajos',
    {'facturarA': 'Constructora Andina SAC', 'ruc': '20601234567'},
    where: 'cliente = ?',
    whereArgs: ['Juan Ramírez'],
  );
  await db.db.update(
    'trabajos',
    {'facturarA': 'Minera Eco Pampa SAA'},
    where: 'cliente = ?',
    whereArgs: ['Minera Eco Pampa'],
  );
  await db.db.update(
    'trabajos',
    {'facturarA': 'Agrícola del Norte EIRL'},
    where: 'cliente = ?',
    whereArgs: ['Carmen Díaz'],
  );

  await recordatorios.crear(const Recordatorio(
    descripcion: 'Cambiar filtro del compresor de Juan',
    fecha: '2026-09-09',
    repite: Repeticion(3, UnidadRepeticion.meses),
    cliente: 'Juan Ramírez',
    equipo: 'Compresor Atlas',
    importante: true,
  ));
  await recordatorios.crear(const Recordatorio(
    descripcion: 'Revisar rodamientos del grupo electrógeno',
    fecha: '2026-08-28',
    cliente: 'Minera Eco Pampa',
  ));
  await recordatorios.crear(const Recordatorio(
    descripcion: 'Engrase mensual de la bomba',
    fecha: '2026-12-01',
    repite: Repeticion(15, UnidadRepeticion.dias),
    cliente: 'Luis Paredes',
  ));
  await recordatorios.crear(Recordatorio(
    descripcion: 'Entregar la bomba reparada',
    fecha: hoyISO(),
    cliente: 'Luis Paredes',
    equipo: 'Bomba de agua',
  ));

  // El historial: octubre con algo de cada cosa, y un año anterior para que
  // aparezca el selector de año.
  Future<int> pasado(String texto, String fecha, {String? cliente}) =>
      recordatorios.crear(
        Recordatorio(descripcion: texto, fecha: fecha, cliente: cliente),
      );

  await recordatorios.marcarCumplido(
    await pasado('Cambio de aceite', '2026-10-12', cliente: 'Juan Ramírez'),
  );
  await recordatorios.marcarCumplido(
    await pasado('Revisar correas', '2026-10-20', cliente: 'Minera Eco Pampa'),
  );
  await pasado('Ajustar frenos', '2026-10-25', cliente: 'Luis Paredes');
  await recordatorios.eliminar(
    await pasado('Limpiar radiador', '2026-10-28', cliente: 'Luis Paredes'),
  );
  await recordatorios.marcarCumplido(
    await pasado('Cambio de batería', '2026-03-03', cliente: 'Juan Ramírez'),
  );
  await recordatorios.marcarCumplido(
    await pasado('Inspección anual', '2025-06-15', cliente: 'Minera Eco Pampa'),
  );

  await recordatorios.refrescarVencidos();
}

/// Deja el acceso como si ya se hubiera cambiado la contraseña y, si se pasa,
/// vinculado un correo. Pocas vueltas: acá se retrata, no se protege.
Future<void> _ponerClave(String clave, {String? correo}) async {
  final huella = HuellaClave.de(clave, vueltas: 500);
  await base_.db.update(
    'auth',
    {
      'claveHuella': huella.huella,
      'claveSal': huella.sal,
      'claveVueltas': huella.vueltas,
      'correo': correo,
    },
    where: 'id = 1',
  );
}

/// Deja avanzar lo que tarda de verdad —la base, el isolate de la huella—
/// hasta que aparece [objetivo].
///
/// Hace falta cuando una acción encadena varios pasos asíncronos reales:
/// [_asentar] deja correr uno solo, y la captura salía con el spinner. Si el
/// objetivo nunca aparece, falla en voz alta: con `--update-goldens` una
/// captura siempre "pasa", así que sin esto retrataría un estado a medias.
Future<void> _esperarA(WidgetTester tester, Finder objetivo) async {
  for (var i = 0; i < 50 && objetivo.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(objetivo, findsWidgets);
}
