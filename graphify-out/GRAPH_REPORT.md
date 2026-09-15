# Graph Report - taller_repuestos  (2026-09-13)

## Corpus Check
- 204 files · ~246,431 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2261 nodes · 3277 edges · 135 communities (122 shown, 9 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 140 edges (avg confidence: 0.86)
- Token cost: 696,948 input · 0 output

## Community Hubs (Navigation)
- Ventana Win32 Windows
- Tokens de diseño
- Utilidades fechas y letras
- Entidad Trabajo y fotos
- Pasos del wizard
- Repositorio de acceso SQLite
- Pantalla datos del negocio
- Arnés de capturas golden
- Pantalla historial
- Selector de repuestos
- Estado Riverpod compartido
- Contratos trabajos y recordatorios
- Tipografía y transiciones
- Capturas pantallas principales
- Movimiento y animaciones
- Generador de PDF
- Login y ciclo de sesión
- Ventana recuperación por correo
- Pantalla recordatorios
- Base de datos y migraciones
- Wizard de trabajo
- Avisos y regresión golden
- Runner Linux GTK
- Controlador de registro
- Animación de apertura
- Tarjetas resumen historial
- Widget Campo de formulario
- Venta simple de repuestos
- Contenedores y estados vacíos
- Tests de acceso
- Entidad Recordatorio
- Contrato de acceso
- Repositorio de trabajos
- Pulsable y barra de acción
- Formulario de repuesto
- Tests de migraciones
- Cableado de providers
- Pantalla de documento
- Validación DNI y RUC
- Formulario de recordatorio
- Repositorio de inventario
- Pantalla de respaldo
- Repositorio de recordatorios
- Respaldo ZIP
- Assets iOS por defecto
- Selector de repetición
- Filtros del historial
- Capturas cobro y acciones
- Pantalla de inventario
- Huella de contraseña PBKDF2
- Contrato de inventario
- Cuenta falsa de pruebas
- Barra superior y menú
- Chips y arranque fallido
- Galería de fotos
- Líneas de documento
- Repetición de recordatorios
- Contrato cuenta remota
- Raíz de la app
- Barra inferior flotante
- Cuenta Firebase
- Servicio de fotos
- Escáner de código
- Textura y miniaturas
- Tabla de ítems
- Formulario cambiar contraseña
- Agregar mano de obra
- Totales y boletas
- Shell principal
- Campo documento DNI RUC
- Contrato de respaldo
- Tests de respaldo
- Entidad Negocio
- Ventanas modales
- Validadores de formulario
- Entidad Repuesto
- Utilidades de texto
- Entidad Foto
- Íconos macOS y web
- Resumen de totales
- Dinero e IGV
- Tests de repositorios
- Plugins macOS registrados
- Entrada Windows
- Apertura y recordatorios
- Tests resumen del taller
- Manifiesto web PWA
- CI GitHub Pages
- Calculadora de totales
- Imágenes base64
- Runner iOS
- Filas pulsables
- Tests de fotos
- Principios de producto
- Campo de fecha
- Repositorio de negocio
- Reglas de acceso y sesión
- Íconos Android
- AppDelegate iOS
- Arranque main.dart
- Runner macOS
- Códigos de barras EAN
- SQLite en web
- Tests de utilidades
- Paquete y dependencias
- Acciones de inventario
- Tests validación y repetición
- Capturas fotos y respaldo
- Capturas login con correo
- Hooks de prueba de base
- Servidor web de desarrollo
- Contrato de negocio
- AppDelegate macOS
- Ventana Flutter macOS
- Build CMake Linux
- Decisiones de respaldo
- Recuperación por correo docs
- Capturas ventana de correo
- Build CMake Windows
- Logo de marca MS
- Pintura de apertura
- Reglas de cobro
- MainActivity Android
- Entrada suave
- Curva muelle
- Fábrica de base
- Tipo de trabajo
- Lanzamiento iOS
- Tipo bool nulo
- Tipo String nulo
- Mano de obra sin cantidad

## God Nodes (most connected - your core abstractions)
1. `_` - 63 edges
2. `_` - 39 edges
3. `Win32Window` - 24 edges
4. `_` - 21 edges
5. `negocioProvider` - 19 edges
6. `refrescoInventarioProvider` - 18 edges
7. `Flutter Default Logo Artwork (iOS App Icon)` - 16 edges
8. `_` - 15 edges
9. `_` - 14 edges
10. `AppDatabase` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Capturas de pantalla (goldens en test/capturas/)` --semantically_similar_to--> `Workflow: Publicar en Pages`  [INFERRED] [semantically similar]
  README.md → .github/workflows/pages.yml
- `Job construir (analyze, test, build web)` --shares_data_with--> `base href $FLUTTER_BASE_HREF placeholder`  [INFERRED]
  .github/workflows/pages.yml → web/index.html
- `Job construir (analyze, test, build web)` --references--> `Analyzer config (flutter_lints, excluye plataformas)`  [INFERRED]
  .github/workflows/pages.yml → analysis_options.yaml
- `Job construir (analyze, test, build web)` --references--> `Tag de test 'capturas' (skip por defecto)`  [INFERRED]
  .github/workflows/pages.yml → dart_test.yaml
- `Job construir (analyze, test, build web)` --references--> `Paquete taller_repuestos 1.1.0+2`  [INFERRED]
  .github/workflows/pages.yml → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Las reglas que no se negocian** — readme_igv_included_rule, readme_traslado_rule, readme_dos_boletas_rule, readme_mano_de_obra_rule, readme_stock_por_linea_rule, readme_fechas_iso_rule, readme_sesion_dura_el_dia, readme_password_pbkdf2, readme_email_recovery_not_gatekeeper, readme_migraciones_defensivas, readme_fotos_tabla_propia, readme_recordatorios_intervalo_libre [EXTRACTED 1.00]
- **Tres reglas de producto (offline, no SUNAT, una mano)** — readme_ms_app, readme_offline_first, readme_not_sunat_invoicing, readme_one_hand_usage [EXTRACTED 1.00]
- **Pipeline de vista previa web en GitHub Pages** — _github_workflows_pages_publicar_en_pages, _github_workflows_pages_construir, _github_workflows_pages_publicar, pubspec_sqflite_common_ffi_web, web_index_base_href, web_index_flutter_bootstrap, readme_web_preview [INFERRED 0.85]
- **MS Logo Visual Composition** — assets_img_logo_ms_monogram, assets_img_logo_multimeter_icon, assets_img_logo_gold_silver_swoosh [EXTRACTED 1.00]
- **Android launcher icon rendered at all mipmap densities (mdpi to xxxhdpi)** — android_app_src_main_res_mipmap_mdpi_ic_launcher, android_app_src_main_res_mipmap_hdpi_ic_launcher, android_app_src_main_res_mipmap_xhdpi_ic_launcher, android_app_src_main_res_mipmap_xxhdpi_ic_launcher, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher [EXTRACTED 1.00]
- **iOS AppIcon Set - Flutter logo rendered at all required iPhone/iPad/App Store sizes** — ios_runner_assets_xcassets_appicon_appiconset_icon_app_1024x1024_1x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_1x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_2x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_20x20_3x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_1x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_2x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_29x29_3x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_1x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_2x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_40x40_3x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_2x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_60x60_3x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_1x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_76x76_2x_icon, ios_runner_assets_xcassets_appicon_appiconset_icon_app_83_5x83_5_2x_icon [EXTRACTED 1.00]
- **iOS LaunchImage Set - blank placeholder at @1x/@2x/@3x** — ios_runner_assets_xcassets_launchimage_imageset_launchimage_image, ios_runner_assets_xcassets_launchimage_imageset_launchimage_2x_image, ios_runner_assets_xcassets_launchimage_imageset_launchimage_3x_image [EXTRACTED 1.00]
- **macOS AppIcon set still using Flutter placeholder artwork** — macos_runner_assets_xcassets_appicon_appiconset_app_icon_16_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_32_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_64_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_128_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_256_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_512_icon, macos_runner_assets_xcassets_appicon_appiconset_app_icon_1024_icon [EXTRACTED 1.00]
- **Web/PWA icon set branded with MS multimeter logo** — web_favicon_icon, web_icons_icon_192_icon, web_icons_icon_512_icon, web_icons_icon_maskable_192_icon, web_icons_icon_maskable_512_icon [EXTRACTED 1.00]
- **Main shell tab screens sharing business header and bottom nav** — test_capturas_1_historial, test_capturas_4_recordatorios, test_capturas_5_inventario, test_capturas_1_historial_business_header, test_capturas_1_historial_bottom_nav_fab [INFERRED 0.95]
- **Colored status pill badges (Sin cerrar, Vencido, Agotado/en stock)** — test_capturas_1_historial_sin_cerrar_badge, test_capturas_4_recordatorios_vencido_badge, test_capturas_5_inventario_stock_badge [INFERRED 0.85]
- **Data printed on report and boleta** — test_capturas_2_wizard_cliente_equipo_form, test_capturas_3_negocio_document_header_preview, test_capturas_3_negocio_business_profile_fields, test_capturas_1_historial_business_header [INFERRED 0.85]
- **Work record lifecycle: create, charge, resume/export** — test_capturas_8_ventana_nuevo_registro, test_capturas_6_wizard_cobro_pantalla_que_se_cobra, test_capturas_10_ventana_acciones_acciones_registro, test_capturas_11_tarjeta_stock_lista_historial [INFERRED 0.85]
- **Bottom-sheet modals over the main shell** — test_capturas_8_ventana_nuevo_registro, test_capturas_9_ventana_clave_cambiar_contrasena, test_capturas_10_ventana_acciones_acciones_registro, test_capturas_8_ventana_shell_principal [INFERRED 0.85]
- **Home hero carousel alert cards (agenda, stock)** — test_capturas_8_ventana_tarjeta_hoy_toca, test_capturas_11_tarjeta_stock_alerta_sin_stock, test_capturas_8_ventana_shell_principal [INFERRED 0.75]
- **Email Account Linking, Login and Recovery Flow** — test_capturas_14_login_correo, test_capturas_15_login_rechazo, test_capturas_16_ventana_correo, test_capturas_17_ventana_correo_fabrica, test_capturas_15_login_rechazo_seguir_sin_correo, test_capturas_17_ventana_correo_fabrica_bloqueo_clave_fabrica [INFERRED 0.85]
- **Local-First Data Protection (evidence photos, off-device backup, replace-all restore)** — test_capturas_12_wizard_fotos_fotos_antes_despues, test_capturas_13_respaldo_conteo_datos, test_capturas_13_respaldo_guardar_respaldo, test_capturas_13_respaldo_restaurar_archivo [INFERRED 0.75]
- **Golden test failure artifact set for 5-inventario** — test_failures_5_inventario_masterimage, test_failures_5_inventario_testimage, test_failures_5_inventario_isolateddiff, test_failures_5_inventario_maskeddiff [EXTRACTED 1.00]
- **Inventory screen layout: header, search/QR, filter chips, parts list, reminder snackbar, bottom nav** — test_failures_5_inventario_testimage_encabezado_negocio, test_failures_5_inventario_testimage_busqueda_qr, test_failures_5_inventario_testimage_filtros_stock, test_failures_5_inventario_testimage_lista_repuestos, test_failures_5_inventario_testimage_boton_nuevo_repuesto, test_failures_5_inventario_testimage_aviso_recordatorio_vencido, test_failures_5_inventario_testimage_barra_navegacion_inferior [EXTRACTED 1.00]

## Communities (135 total, 9 thin omitted)

### Community 0 - "Ventana Win32 Windows"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 1 - "Tokens de diseño"
Cohesion: 0.04
Nodes (58): _, acciones, alta, amplio, Ancho, apagadoFondo, apagadoTexto, baja (+50 more)

### Community 2 - "Utilidades fechas y letras"
Cohesion: 0.04
Nodes (46): a, claveMes, d, destino, dia, _dos, estaVencida, fechaDe (+38 more)

### Community 3 - "Entidad Trabajo y fotos"
Cohesion: 0.05
Nodes (43): foto.dart, aQuienFacturar, cliente, cobraTraslado, codigo, copyWith, descuento, diagnostico (+35 more)

### Community 4 - "Pasos del wizard"
Cohesion: 0.06
Nodes (42): ../../comunes/agregar_mano_obra.dart, ../../comunes/galeria_fotos.dart, activo, bloqueado, build, _cambiarTipo, campos, cliente (+34 more)

### Community 5 - "Repositorio de acceso SQLite"
Cohesion: 0.05
Nodes (42): ../cuenta/cuenta_remota.dart, abrirSesion, _anotarFallo, _base, cambiarClave, cerrarSesion, _claveEspera, _claveFallos (+34 more)

### Community 6 - "Pantalla datos del negocio"
Cohesion: 0.06
Nodes (35): ../../../core/widgets/campo_documento.dart, generadorPdfProvider, negocioProvider, build, build, _descargar, _pdfDe, _descargar (+27 more)

### Community 7 - "Arnés de capturas golden"
Cohesion: 0.06
Nodes (35): package:taller_repuestos/app/providers.dart, package:taller_repuestos/core/theme/app_theme.dart, package:taller_repuestos/presentation/features/apertura/pantalla_apertura.dart, package:taller_repuestos/presentation/features/auth/pantalla_login.dart, package:taller_repuestos/presentation/features/negocio/pantalla_negocio.dart, package:taller_repuestos/presentation/features/negocio/pantalla_respaldo.dart, package:taller_repuestos/presentation/features/shell/shell_principal.dart, package:taller_repuestos/presentation/features/trabajo/wizard_trabajo.dart (+27 more)

### Community 8 - "Pantalla historial"
Cohesion: 0.06
Nodes (33): ../../../core/widgets/foto.dart, filtros_historial.dart, _abrir, acepta, activo, actual, cantidad, _cargando (+25 more)

### Community 9 - "Selector de repuestos"
Cohesion: 0.06
Nodes (32): InventarioRepository get, _agregarConDetalle, _agregarUno, autofoco, _busqueda, cantidad, _cargar, _confirmar (+24 more)

### Community 10 - "Estado Riverpod compartido"
Cohesion: 0.11
Nodes (32): ConsumerState, ConsumerStatefulWidget, pedidoAgotadosProvider, refrescoHistorialProvider, refrescoInventarioProvider, refrescoRecordatoriosProvider, resumenProvider, vencidosProvider (+24 more)

### Community 11 - "Contratos trabajos y recordatorios"
Cohesion: 0.06
Nodes (29): ../entities/recordatorio.dart, ../entities/repeticion.dart, ../entities/trabajo.dart, actualizar, contarVencidos, crear, crearDesdeTrabajo, eliminar (+21 more)

### Community 12 - "Tipografía y transiciones"
Cohesion: 0.07
Nodes (31): _, AppTheme, _borde, claro, _texto, _TransicionDeslizar, _, boton (+23 more)

### Community 13 - "Capturas pantallas principales"
Cohesion: 0.10
Nodes (31): Bienvenida splash screenshot, Roll-up metal shutter background, MS logo spark reveal animation, Historial screen screenshot, Floating bottom nav with central + FAB (Historial/Inventario/Avisos), Business header bar (Servicios MS, RUC, logo), Hoy toca reminder carousel, Buscar cliente o equipo search with filter button (+23 more)

### Community 14 - "Movimiento y animaciones"
Cohesion: 0.07
Nodes (30): AnimationController, _, apertura, build, _c, child, createState, desplazamiento (+22 more)

### Community 15 - "Generador de PDF"
Cohesion: 0.07
Nodes (29): ../../core/utils/letras.dart, _armar, _bloqueTotales, _boleta, _cabecera, _cargarLogo, completo, _fotos (+21 more)

### Community 16 - "Login y ciclo de sesión"
Cohesion: 0.08
Nodes (29): didChangeAppLifecycleState, _raiz, authRepoProvider, alEntrar, _Cabecera, _clave, correo, createState (+21 more)

### Community 17 - "Ventana recuperación por correo"
Cohesion: 0.07
Nodes (29): _avisarSiYaCerro, build, _clave, _claveApp, _claveCuenta, _confirmado, conNube, _correo (+21 more)

### Community 18 - "Pantalla recordatorios"
Cohesion: 0.07
Nodes (28): formulario_recordatorio.dart, IconData get, _abrirFormulario, activa, _bloque, cantidad, _cargando, _contenido (+20 more)

### Community 19 - "Base de datos y migraciones"
Cohesion: 0.07
Nodes (27): ../../core/utils/clave_segura.dart, ../../core/utils/imagenes.dart, Database, fabrica_db.dart, abrir, _agregarColumna, _archivoDb, cerrar (+19 more)

### Community 20 - "Wizard de trabajo"
Cohesion: 0.07
Nodes (27): GlobalKey, CamposWizard, _alCambiar, _atras, _bloqueado, build, _campos, _cantidadPasos (+19 more)

### Community 21 - "Avisos y regresión golden"
Cohesion: 0.09
Nodes (27): aceptar, cancelar, confirmar, confirmarSalida, destructivo, false, informar, mostrarAviso (+19 more)

### Community 22 - "Runner Linux GTK"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 23 - "Controlador de registro"
Cohesion: 0.08
Nodes (25): agregarManoDeObra, agregarRepuestos, cambiarCantidad, cargar, descartar, editar, empezar, esNuevo (+17 more)

### Community 24 - "Animación de apertura"
Cohesion: 0.08
Nodes (24): Animation, _alto, avance, _bajada, child, createState, dispose, _entrada (+16 more)

### Community 25 - "Tarjetas resumen historial"
Cohesion: 0.08
Nodes (24): _Contenido, ../../../core/widgets/textura.dart, ../../../domain/entities/resumen_taller.dart, _actual, build, cantidad, _Contenido, createState (+16 more)

### Community 26 - "Widget Campo de formulario"
Cohesion: 0.08
Nodes (24): autofoco, ayuda, build, Campo, controlador, decimalFormato, ejemplo, etiqueta (+16 more)

### Community 27 - "Venta simple de repuestos"
Cohesion: 0.08
Nodes (23): ChangeNotifier, ../../comunes/campo_fecha.dart, ../../comunes/controlador_registro.dart, ../../comunes/selector_repuesto.dart, ../../../core/widgets/resumen_totales.dart, ../../../core/widgets/tabla_items.dart, ../documento/pantalla_documento.dart, ControladorRegistro (+15 more)

### Community 28 - "Contenedores y estados vacíos"
Cohesion: 0.08
Nodes (23): EdgeInsets, accion, ancho, build, child, color, Contenido, createState (+15 more)

### Community 29 - "Tests de acceso"
Cohesion: 0.10
Nodes (21): Duration, ../falsos/cuenta_falsa.dart, AppDatabase, AuthRepositorySqlite, AuthRepository, package:shared_preferences/shared_preferences.dart, package:taller_repuestos/data/cuenta/cuenta_remota.dart, package:taller_repuestos/data/repositories/auth_repository_sqlite.dart (+13 more)

### Community 30 - "Entidad Recordatorio"
Cohesion: 0.09
Nodes (22): cliente, copyWith, cumplido, descripcion, equipo, estado, EstadoRecordatorio, fecha (+14 more)

### Community 31 - "Contrato de acceso"
Cohesion: 0.09
Nodes (22): abrirSesion, aviso, cambiarClave, cerrarSesion, claveDeFabrica, conCorreo, correcto, correo (+14 more)

### Community 32 - "Repositorio de trabajos"
Cohesion: 0.09
Nodes (21): ../../domain/repositories/inventario_repository.dart, ../../../domain/repositories/trabajos_repository.dart, InventarioRepositorySqlite, actualizar, _base, crear, _db, editarPaso (+13 more)

### Community 33 - "Pulsable y barra de acción"
Cohesion: 0.10
Nodes (20): double?, build, child, createState, escala, _hundido, _marcar, onLongPress (+12 more)

### Community 34 - "Formulario de repuesto"
Cohesion: 0.10
Nodes (20): ../../../core/utils/codigo_barras.dart, _AvisoDuplicado, build, _codigo, createState, dispose, _escanear, _esEdicion (+12 more)

### Community 35 - "Tests de migraciones"
Cohesion: 0.10
Nodes (19): dart:io, Directory, databaseFactoryFfi, fabricaDb, fabricaDbMemoria, rutaDb, rutaEnMemoria, package:path/path.dart (+11 more)

### Community 36 - "Cableado de providers"
Cohesion: 0.10
Nodes (20): ../data/cuenta/cuenta_remota.dart, ../data/documentos/generador_pdf.dart, ../data/fotos/servicio_fotos.dart, ../data/repositories/auth_repository_sqlite.dart, ../data/repositories/inventario_repository_sqlite.dart, ../data/repositories/negocio_repository_sqlite.dart, ../data/repositories/recordatorios_repository_sqlite.dart, ../data/repositories/trabajos_repository_sqlite.dart (+12 more)

### Community 37 - "Pantalla de documento"
Cohesion: 0.11
Nodes (20): ../../../domain/services/calculadora_totales.dart, trabajosRepoProvider, Trabajo, activa, _boletas, build, _cargar, createState (+12 more)

### Community 38 - "Validación DNI y RUC"
Cohesion: 0.10
Nodes (20): aceptable, d, documentoAceptable, estado, EstadoDocumento, _faltan, _largoDni, _largoRuc (+12 more)

### Community 39 - "Formulario de recordatorio"
Cohesion: 0.11
Nodes (19): class, ../../comunes/barra_accion.dart, ../../comunes/selector_repeticion.dart, build, _cliente, createState, _descripcion, dispose (+11 more)

### Community 40 - "Repositorio de inventario"
Cohesion: 0.10
Nodes (19): ../../../core/utils/texto.dart, ../../../domain/entities/repuesto.dart, actualizar, agregarRepuesto, _base, buscarPorCodigo, codigoRepetido, crear (+11 more)

### Community 41 - "Pantalla de respaldo"
Cohesion: 0.12
Nodes (19): ../../../core/widgets/avisos.dart, ../../../core/widgets/contenido.dart, respaldoRepoProvider, _actual, build, _contar, createState, cuantos (+11 more)

### Community 42 - "Repositorio de recordatorios"
Cohesion: 0.10
Nodes (19): ../../../domain/entities/recordatorio.dart, ../../../domain/entities/repeticion.dart, ../../../domain/entities/trabajo.dart, ../../domain/repositories/recordatorios_repository.dart, actualizar, _base, contarVencidos, crear (+11 more)

### Community 43 - "Respaldo ZIP"
Cohesion: 0.10
Nodes (19): ../../../domain/repositories/respaldo_repository.dart, _abrir, _archivoDatos, _base, _carpetaFotos, _contar, _db, exportar (+11 more)

### Community 44 - "Assets iOS por defecto"
Cohesion: 0.10
Nodes (20): Flutter Default Logo Artwork (iOS App Icon), iOS App Icon 1024x1024@1x (App Store), iOS App Icon 20x20@1x (Notification), iOS App Icon 20x20@2x (Notification), iOS App Icon 20x20@3x (Notification), iOS App Icon 29x29@1x (Settings), iOS App Icon 29x29@2x (Settings), iOS App Icon 29x29@3x (Settings) (+12 more)

### Community 45 - "Selector de repetición"
Cohesion: 0.10
Nodes (19): activo, _atajos, bloqueado, build, _cambiarCantidad, _Chip, desde, habilitado (+11 more)

### Community 46 - "Filtros del historial"
Cohesion: 0.10
Nodes (19): _abierto, activo, _BotonFiltros, build, _busqueda, _Chip, createState, dispose (+11 more)

### Community 47 - "Capturas cobro y acciones"
Cohesion: 0.14
Nodes (20): Record actions sheet (Ver documento, Seguir cargando, Descargar PDF), Record document / PDF export, Estado Sin cerrar (draft/unclosed record), Sin stock alert card (out-of-stock part), Historial home with Sin stock alert card (Faja A-52), History list with search and filter chips (Todos/Pendientes/Completados), Order code REP-2026-0004, Wizard Step 4: Que se cobra (charges screen) (+12 more)

### Community 48 - "Pantalla de inventario"
Cohesion: 0.11
Nodes (18): ../../comunes/filtro_chips.dart, ../../../core/widgets/escaner_codigo.dart, formulario_repuesto.dart, _agotados, _busqueda, _cargando, createState, dispose (+10 more)

### Community 49 - "Huella de contraseña PBKDF2"
Cohesion: 0.11
Nodes (18): dart:math, coincide, de, diferencia, hmac, huella, HuellaClave, igualesEnTiempoConstante (+10 more)

### Community 50 - "Contrato de inventario"
Cohesion: 0.11
Nodes (18): ../entities/repuesto.dart, actualizar, agregarRepuesto, aviso, buscarPorCodigo, codigoRepetido, crear, devolverRepuesto (+10 more)

### Community 51 - "Cuenta falsa de pruebas"
Cohesion: 0.11
Nodes (18): Map, Set, cambiarClave, cambioLlegaIgual, confirmaciones, correoVerificado, crear, cuentas (+10 more)

### Community 52 - "Barra superior y menú"
Cohesion: 0.12
Nodes (17): ConsumerWidget, ../../../domain/repositories/auth_repository.dart, estadoCuentaProvider, EstadoCuenta, VentanaCorreo, AccionNegocio, avisar, BarraSuperior (+9 more)

### Community 53 - "Chips y arranque fallido"
Cohesion: 0.12
Nodes (16): ../../../core/theme/movimiento.dart, ../../../core/theme/tokens.dart, build, error, PantallaArranqueFallido, traza, build, cantidad (+8 more)

### Community 54 - "Galería de fotos"
Cohesion: 0.12
Nodes (17): ../../../domain/entities/foto.dart, servicioFotosProvider, _agregar, bloqueado, build, createState, foto, fotos (+9 more)

### Community 55 - "Líneas de documento"
Cohesion: 0.12
Nodes (17): double get, cant, cantidad, copyWith, desc, esDeInventario, fromJson, importe (+9 more)

### Community 56 - "Repetición de recordatorios"
Cohesion: 0.12
Nodes (17): int get, cada, corta, deFilas, etiqueta, hashCode, inicial, meses (+9 more)

### Community 57 - "Contrato cuenta remota"
Cohesion: 0.12
Nodes (17): CuentaFirebase, cambiarClave, crear, CuentaNoDisponible, CuentaRemota, disponible, entrar, enviarRecuperacion (+9 more)

### Community 58 - "Raíz de la app"
Cohesion: 0.12
Nodes (16): ../core/theme/app_theme.dart, AppMs, _AppMsState, build, child, createState, _CruceFases, dispose (+8 more)

### Community 59 - "Barra inferior flotante"
Cohesion: 0.12
Nodes (16): ../../../core/widgets/pulsable.dart, dart:ui, activo, BarraInferior, _BotonNuevo, build, etiqueta, icono (+8 more)

### Community 60 - "Cuenta Firebase"
Cohesion: 0.12
Nodes (16): cuenta_remota.dart, dart:async, FirebaseAuth, _auth, cambiarClave, crear, disponible, entrar (+8 more)

### Community 61 - "Servicio de fotos"
Cohesion: 0.12
Nodes (16): ImagePicker, _anchoMaximo, _anchoMini, _calidad, _calidadMini, _capturar, _comprimir, elegir (+8 more)

### Community 62 - "Escáner de código"
Cohesion: 0.12
Nodes (16): _aMano, build, _camara, createState, _devolver, dispose, escanearCodigo, _Mira (+8 more)

### Community 63 - "Textura y miniaturas"
Cohesion: 0.12
Nodes (15): build, foto, _Inicial, lado, Miniatura, nombre, build, cantidad (+7 more)

### Community 64 - "Tabla de ítems"
Cohesion: 0.12
Nodes (15): contenido.dart, ../../domain/entities/linea.dart, build, _Fila, icono, items, linea, mostrarCantidad (+7 more)

### Community 65 - "Formulario cambiar contraseña"
Cohesion: 0.13
Nodes (15): ../../../core/utils/validacion.dart, FormState, _actual, build, createState, dispose, _error, _form (+7 more)

### Community 66 - "Agregar mano de obra"
Cohesion: 0.13
Nodes (15): ../../../core/widgets/campo.dart, _agregar, AgregarManoDeObra, _AgregarManoDeObraState, build, createState, _desc, dispose (+7 more)

### Community 67 - "Totales y boletas"
Cohesion: 0.12
Nodes (15): Boleta, descuento, fromJson, gravado, igv, incluyeManoDeObra, incluyeRepuestos, subRepuestos (+7 more)

### Community 68 - "Shell principal"
Cohesion: 0.13
Nodes (14): barra_inferior.dart, barra_superior.dart, ../../../core/widgets/hoja.dart, ../historial/pantalla_historial.dart, ../inventario/pantalla_inventario.dart, createState, _seccion, ../negocio/formulario_clave.dart (+6 more)

### Community 69 - "Campo documento DNI RUC"
Cohesion: 0.14
Nodes (14): campo.dart, build, CampoDocumento, _CampoDocumentoState, controlador, createState, etiqueta, habilitado (+6 more)

### Community 70 - "Contrato de respaldo"
Cohesion: 0.13
Nodes (14): Exception, exportar, fecha, fotos, motivo, recordatorios, repuestos, RespaldoInvalido (+6 more)

### Community 71 - "Tests de respaldo"
Cohesion: 0.13
Nodes (14): package:archive/archive.dart, package:taller_repuestos/data/repositories/negocio_repository_sqlite.dart, package:taller_repuestos/data/respaldo/respaldo_zip.dart, package:taller_repuestos/domain/entities/negocio.dart, package:taller_repuestos/domain/repositories/respaldo_repository.dart, base, bytes, inventario (+6 more)

### Community 72 - "Entidad Negocio"
Cohesion: 0.14
Nodes (13): bool get, NegocioNotifier, copyWith, direccion, email, estaVacio, fromRow, Negocio (+5 more)

### Community 73 - "Ventanas modales"
Cohesion: 0.14
Nodes (13): Color, IconData, bajada, build, child, color, destacada, detalle (+5 more)

### Community 74 - "Validadores de formulario"
Cohesion: 0.15
Nodes (14): documento.dart, _, descuento, documento, email, entero, minimo, obligatorio (+6 more)

### Community 75 - "Entidad Repuesto"
Cohesion: 0.14
Nodes (13): int?, agotado, c, codigoBarras, copyWith, fromRow, id, nombre (+5 more)

### Community 76 - "Utilidades de texto"
Cohesion: 0.14
Nodes (13): arroba, base, buffer, coincide, _conTilde, limpio, normalizar, ocultarCorreo (+5 more)

### Community 77 - "Entidad Foto"
Cohesion: 0.14
Nodes (13): bytes, copyWith, Foto, fromRow, id, mini, MomentoFoto, paraLista (+5 more)

### Community 78 - "Íconos macOS y web"
Cohesion: 0.15
Nodes (14): Flutter Default Placeholder App Icon, macOS App Icon 1024px (Flutter default logo), macOS App Icon 128px (Flutter default logo), macOS App Icon 16px (Flutter default logo), macOS App Icon 256px (Flutter default logo), macOS App Icon 32px (Flutter default logo), macOS App Icon 512px (Flutter default logo), macOS App Icon 64px (Flutter default logo) (+6 more)

### Community 79 - "Resumen de totales"
Cohesion: 0.15
Nodes (12): ../../../domain/entities/totales.dart, build, destacado, etiqueta, _Fila, _Nota, ResumenTotales, titulo (+4 more)

### Community 80 - "Dinero e IGV"
Cohesion: 0.15
Nodes (12): kIgv, leerNumero, limpio, _numero, redondear, signo, _simbolo, soles (+4 more)

### Community 81 - "Tests de repositorios"
Cohesion: 0.17
Nodes (11): package:taller_repuestos/data/repositories/inventario_repository_sqlite.dart, package:taller_repuestos/domain/entities/linea.dart, package:taller_repuestos/domain/entities/trabajo.dart, package:taller_repuestos/domain/repositories/trabajos_repository.dart, package:taller_repuestos/domain/services/calculadora_totales.dart, base, inventario, main (+3 more)

### Community 82 - "Plugins macOS registrados"
Cohesion: 0.17
Nodes (11): file_picker_darwin, file_selector_macos, firebase_auth, firebase_core, flutter_image_compress_macos, Foundation, mobile_scanner, printing (+3 more)

### Community 83 - "Entrada Windows"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 84 - "Apertura y recordatorios"
Cohesion: 0.18
Nodes (11): recordatoriosRepoProvider, _arrancar, PantallaApertura, _PantallaAperturaState, _guardar, _cargar, _cumplir, _eliminar (+3 more)

### Community 85 - "Tests resumen del taller"
Cohesion: 0.18
Nodes (10): package:taller_repuestos/domain/entities/recordatorio.dart, package:taller_repuestos/domain/entities/repuesto.dart, package:taller_repuestos/domain/entities/resumen_taller.dart, anteayer, armar, ayer, enUnMes, hoy (+2 more)

### Community 86 - "Manifiesto web PWA"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 87 - "CI GitHub Pages"
Cohesion: 0.29
Nodes (10): Job construir (analyze, test, build web), Job publicar (deploy-pages), Workflow: Publicar en Pages, Analyzer config (flutter_lints, excluye plataformas), Tag de test 'capturas' (skip por defecto), mobile_scanner / image_picker (camara), sqflite_common_ffi_web (SQLite en wasm), Capturas de pantalla (goldens en test/capturas/) (+2 more)

### Community 88 - "Calculadora de totales"
Cohesion: 0.20
Nodes (9): ../../../core/utils/dinero.dart, ../entities/linea.dart, ../entities/totales.dart, calculadora, CalculadoraTotales, calcular, calcularBoletas, calcularTraslado (+1 more)

### Community 89 - "Imágenes base64"
Cohesion: 0.20
Nodes (8): dart:convert, dart:typed_data, bytesDeFoto, fotoDesdeBytes, _prefijoJpeg, package:taller_repuestos/core/utils/clave_segura.dart, hex, main

### Community 90 - "Runner iOS"
Cohesion: 0.24
Nodes (6): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTestCase

### Community 91 - "Filas pulsables"
Cohesion: 0.27
Nodes (10): FilaLista, _FilaListaState, Pulsable, _PulsableState, FiltrosHistorial, _FiltrosHistorialState, TarjetasResumen, _TarjetasResumenState (+2 more)

### Community 92 - "Tests de fotos"
Cohesion: 0.20
Nodes (9): package:taller_repuestos/core/utils/imagenes.dart, package:taller_repuestos/data/local/app_database.dart, package:taller_repuestos/data/repositories/trabajos_repository_sqlite.dart, package:taller_repuestos/domain/entities/foto.dart, base, bytes, conFotos, main (+1 more)

### Community 93 - "Principios de producto"
Cohesion: 0.22
Nodes (9): SIL Open Font License 1.1 (Archivo Project Authors), Font family Archivo (assets/fonts/Archivo.ttf), Tipografia Archivo variable (eje wdth via Tipo/FontVariation), Paleta de marca vino #761C1C y oro #87611A, negro como superficie, El correo recupera la contrasena, no decide quien entra, Funciona sin internet (offline-first, datos en el dispositivo), base href $FLUTTER_BASE_HREF placeholder, flutter_bootstrap.js loader (+1 more)

### Community 94 - "Campo de fecha"
Cohesion: 0.22
Nodes (8): ../../../core/theme/tipografia.dart, ../../../core/utils/fechas.dart, build, CampoFecha, etiqueta, fecha, habilitado, onCambio

### Community 95 - "Repositorio de negocio"
Cohesion: 0.22
Nodes (8): Database get, ../../../domain/entities/negocio.dart, ../../domain/repositories/negocio_repository.dart, _base, _db, guardar, obtener, ../local/app_database.dart

### Community 96 - "Reglas de acceso y sesión"
Cohesion: 0.22
Nodes (9): crypto, Contrasena de fabrica (sin huella), Fechas ISO corto sin hora ni zona horaria, Uso con una mano (area tactil minima 44px), Contrasena guardada como huella PBKDF2-SHA256 con sal, Recordatorios con intervalo libre en la unidad elegida, La sesion dura el dia, Stock se mueve al agregar/quitar cada linea (+1 more)

### Community 97 - "Íconos Android"
Cohesion: 0.39
Nodes (8): Android Launcher Icon (hdpi), Android Launcher Icon (mdpi), Android Launcher Icon (xhdpi), Android Launcher Icon (xxhdpi), Android Launcher Icon (xxxhdpi), Density-Specific Android Launcher Icon Set (mipmap), MS Brand Logo (monogram with multimeter and gold/silver crescent), Multimeter Motif (electrical/repair workshop symbol)

### Community 98 - "AppDelegate iOS"
Cohesion: 0.25
Nodes (6): Any, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, UIApplication

### Community 99 - "Arranque main.dart"
Cohesion: 0.25
Nodes (7): app/app.dart, app/pantalla_arranque_fallido.dart, ../../../app/providers.dart, data/cuenta/cuenta_firebase.dart, ../../../data/local/app_database.dart, main, package:flutter_riverpod/flutter_riverpod.dart

### Community 100 - "Runner macOS"
Cohesion: 0.32
Nodes (4): Cocoa, FlutterMacOS, RunnerTests, XCTest

### Community 101 - "Códigos de barras EAN"
Cohesion: 0.25
Nodes (7): c, codigoBarrasValido, digitos, esCodigoVerificable, esperado, suma, verificadorEan

### Community 102 - "SQLite en web"
Cohesion: 0.25
Nodes (7): fabricaDb, fabricaDbMemoria, rutaDb, rutaEnMemoria, package:sqflite_common_ffi_web/sqflite_ffi_web.dart, package:sqflite_common/sqlite_api.dart, String get

### Community 103 - "Tests de utilidades"
Cohesion: 0.25
Nodes (7): package:taller_repuestos/core/utils/codigo_barras.dart, package:taller_repuestos/core/utils/dinero.dart, package:taller_repuestos/core/utils/documento.dart, package:taller_repuestos/core/utils/fechas.dart, package:taller_repuestos/core/utils/letras.dart, package:taller_repuestos/core/utils/texto.dart, main

### Community 104 - "Paquete y dependencias"
Cohesion: 0.36
Nodes (8): flutter_riverpod (estado), pdf + printing (documentos), sqflite_common (API pura, compila para web), Paquete taller_repuestos 1.1.0+2, Arquitectura en capas Widget -> Controlador -> Repositorio -> SQLite, MS - trabajos, repuestos y documentos (app), No es facturacion electronica SUNAT, app/providers.dart (unico cableado de contratos)

### Community 105 - "Acciones de inventario"
Cohesion: 0.29
Nodes (7): inventarioRepoProvider, _cargarInventario, _guardar, _sumarAlExistente, _buscarPorCodigo, _cargar, _eliminar

### Community 106 - "Tests validación y repetición"
Cohesion: 0.29
Nodes (5): package:flutter_test/flutter_test.dart, package:taller_repuestos/core/utils/validacion.dart, package:taller_repuestos/domain/entities/repeticion.dart, main, main

### Community 107 - "Capturas fotos y respaldo"
Cohesion: 0.29
Nodes (7): Screenshot: Wizard Step 2 - Fotos, Record Code Format REP-YYYY-NNNN, Before/After Photo Evidence (Como llego / Como quedo), 6-Step Repair Wizard with Segmented Progress Bar, Screenshot: Respaldo (Backup) Screen, On-Device Data Counts (Registros, Repuestos, Recordatorios, Fotos), Restaurar desde un Archivo (Replace-All Restore)

### Community 108 - "Capturas login con correo"
Cohesion: 0.33
Nodes (7): Guardar Respaldo via Share Sheet (Drive/WhatsApp), Screenshot: Login with Linked Email Account, Servicios MS Brand Header (maroon/gold, multimeter logo), Olvidaste tu Contrasena Link, Screenshot: Login Rejected by Email Account, Remote Password Mismatch Error Banner, Seguir sin el Correo (Offline Fallback)

### Community 109 - "Hooks de prueba de base"
Cohesion: 0.33
Nodes (6): @visibleForTesting, abrirEn, _actualizar, crearEsquema, mudarFotos, protegerClaves

### Community 111 - "Contrato de negocio"
Cohesion: 0.33
Nodes (5): ../entities/negocio.dart, NegocioRepositorySqlite, guardar, NegocioRepository, obtener

### Community 112 - "AppDelegate macOS"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 113 - "Ventana Flutter macOS"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 114 - "Build CMake Linux"
Cohesion: 0.40
Nodes (5): APPLY_STANDARD_SETTINGS (Linux), Linux CMake project (BINARY_NAME taller_repuestos, APPLICATION_ID com.example.taller_repuestos), flutter_assemble target (Linux tool_backend.sh), flutter INTERFACE library (libflutter_linux_gtk.so), Linux runner executable (main.cc, my_application.cc)

### Community 115 - "Decisiones de respaldo"
Cohesion: 0.33
Nodes (6): archive + share_plus + file_picker (respaldo), Pendiente: respaldo automatico en la nube (Cloud Storage requiere Blaze), Fotos en tabla propia con bytes crudos y miniatura ~8KB, Migraciones que miran antes de tocar, Respaldo ZIP (datos.json + fotos/<id>.jpg), Restaurar reemplaza, no mezcla

### Community 116 - "Recuperación por correo docs"
Cohesion: 0.40
Nodes (6): firebase_core + firebase_auth, Build APK release (Kotlin incremental desactivado en Windows), data/cuenta/cuenta_firebase.dart (unico que importa Firebase), Recuperacion de contrasena por correo (Firebase Auth plan Spark), Escritorio de Windows no es destino, Windows CMake project taller_repuestos

### Community 117 - "Capturas ventana de correo"
Cohesion: 0.40
Nodes (6): Masked Account Email (wi••••••@gmail.com), Screenshot: Recuperacion por Correo Dialog (Link Email), Home Shell (Hoy Toca carousel, Historial list, bottom nav, FAB), Vincular Correo (Email + App Password Confirmation), Screenshot: Email Dialog Blocked by Factory Password, Factory Default Password Guard

### Community 118 - "Build CMake Windows"
Cohesion: 0.60
Nodes (6): APPLY_STANDARD_SETTINGS (Windows), flutter_assemble target (Windows tool_backend.bat), flutter INTERFACE library (flutter_windows.dll), flutter_wrapper_app static library, flutter_wrapper_plugin static library, Windows runner executable (flutter_window.cpp, main.cpp, win32_window.cpp)

### Community 119 - "Logo de marca MS"
Cohesion: 0.60
Nodes (5): Gold and Silver Circular Swoosh, MS Brand Logo (logo.png), MS Monogram, Multimeter Icon (electrical diagnostics), Repair Shop / Parts Business Brand Identity

### Community 120 - "Pintura de apertura"
Cohesion: 0.50
Nodes (4): CustomPainter, EstriasDiagonales, _Bandas, _Chispas

### Community 121 - "Reglas de cobro"
Cohesion: 0.67
Nodes (4): CalculadoraTotales (reglas de plata), Dos boletas separadas suman igual que la junta, IGV 18% incluido en los precios, Traslado solo en campo y con movilidad propia

### Community 123 - "Entrada suave"
Cohesion: 0.67
Nodes (3): EntradaSuave, _EntradaSuaveState, SingleTickerProviderStateMixin

## Ambiguous Edges - Review These
- `clave_segura.dart` → `Factory Default Password Guard`  [AMBIGUOUS]
  test/capturas/17-ventana-correo-fabrica.png · relation: conceptually_related_to
- `MS Monogram` → `Repair Shop / Parts Business Brand Identity`  [AMBIGUOUS]
  assets/img/logo.png · relation: conceptually_related_to
- `Flutter Default Placeholder App Icon` → `MS Brand Logo (multimeter over MS monogram)`  [AMBIGUOUS]
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png · relation: conceptually_related_to
- `Pendientes para hoy reminder list` → `Spare part list (name, stock, price, delete)`  [AMBIGUOUS]
  test/capturas/5-inventario.png · relation: conceptually_related_to

## Knowledge Gaps
- **1335 isolated node(s):** `_Fase`, `child`, `createState`, `initState`, `dispose` (+1330 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1536 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `clave_segura.dart` and `Factory Default Password Guard`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `MS Monogram` and `Repair Shop / Parts Business Brand Identity`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Flutter Default Placeholder App Icon` and `MS Brand Logo (multimeter over MS monogram)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Pendientes para hoy reminder list` and `Spare part list (name, stock, price, delete)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `_` connect `Tokens de diseño` to `Animación de apertura`, `Utilidades fechas y letras`, `Respaldo ZIP`, `Chips y arranque fallido`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `Tests de acceso` to `Repositorio de trabajos`, `Cableado de providers`, `Repositorio de acceso SQLite`, `Arnés de capturas golden`, `Repositorio de inventario`, `Tests de respaldo`, `Repositorio de recordatorios`, `Respaldo ZIP`, `Tests de repositorios`, `Base de datos y migraciones`, `Tests de fotos`, `Repositorio de negocio`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `_` connect `Movimiento y animaciones` to `Pulsable y barra de acción`, `Tipografía y transiciones`, `Cuenta Firebase`, `Chips y arranque fallido`, `Entrada suave`, `Curva muelle`, `Tests de acceso`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._