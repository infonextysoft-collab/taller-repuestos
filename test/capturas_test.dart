@Tags(['capturas'])
library;

import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_repuestos/app/providers.dart';
import 'package:taller_repuestos/core/theme/app_theme.dart';
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
import 'package:taller_repuestos/presentation/features/apertura/pantalla_apertura.dart';
import 'package:taller_repuestos/presentation/features/auth/pantalla_login.dart';
import 'package:taller_repuestos/presentation/features/negocio/pantalla_negocio.dart';
import 'package:taller_repuestos/presentation/features/shell/shell_principal.dart';
import 'package:taller_repuestos/presentation/features/trabajo/wizard_trabajo.dart';

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

  testWidgets('inventario', (tester) async {
    await _mostrar(tester, ShellPrincipal(alSalir: () async {}));
    await tester.tap(find.byIcon(Icons.inventory_2_rounded).first);
    await _asentar(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('capturas/5-inventario.png'),
    );
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
      overrides: [baseDatosProvider.overrideWithValue(base_)],
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

/// El registro a medias, para retratar el wizard en un paso del medio.
late int pendienteId;

Future<void> _sembrar(AppDatabase db) async {
  base_ = db;

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
  ));

  await inventario.crear(const Repuesto(
    nombre: 'Filtro de aceite',
    stock: 12,
    precio: 38.5,
  ));
  await inventario.crear(const Repuesto(
    nombre: 'Rodamiento 6205',
    stock: 3,
    precio: 22,
  ));
  await inventario.crear(const Repuesto(nombre: 'Faja A-52', precio: 45));

  Future<void> registrar({
    required TipoTrabajo tipo,
    required String cliente,
    required String equipo,
    required String fecha,
    required double mano,
    bool cerrado = true,
  }) async {
    final creado = await trabajos.crear(Trabajo(tipo: tipo, fecha: fecha));
    final lleno = await trabajos.actualizar(creado.copyWith(
      cliente: cliente,
      equipo: equipo,
      diagnostico: 'Revisión general',
      trabajosRealizados: [LineaMano(desc: 'Mantenimiento', precio: mano)],
      repuestos: const [
        LineaRepuesto(desc: 'Filtro de aceite', cantidad: 1, precio: 38.5),
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
  await recordatorios.refrescarVencidos();
}
