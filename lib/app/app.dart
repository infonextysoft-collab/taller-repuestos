import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/movimiento.dart';
import '../presentation/features/apertura/pantalla_apertura.dart';
import '../presentation/features/auth/pantalla_login.dart';
import '../presentation/features/shell/shell_principal.dart';
import 'providers.dart';

/// Qué se está mostrando en la raíz de la app.
enum _Fase { apertura, login, dentro }

/// La app. Solo decide qué hay en la raíz; todo lo demás vive en su feature.
class AppMs extends ConsumerStatefulWidget {
  const AppMs({super.key});

  @override
  ConsumerState<AppMs> createState() => _AppMsState();
}

class _AppMsState extends ConsumerState<AppMs> with WidgetsBindingObserver {
  _Fase _fase = _Fase.apertura;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// La sesión dura el día, y el día cambia mientras la app está guardada en
  /// segundo plano — un celular puede quedarse con la app abierta una semana.
  ///
  /// Se revisa **al volver al frente**, no con un temporizador: así nunca te
  /// echa mientras estás escribiendo un registro. Si pasó la medianoche, al
  /// retomar la app pide la contraseña otra vez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed || _fase != _Fase.dentro) return;

    ref.read(authRepoProvider).haySesion().then((sigue) {
      if (!sigue && mounted) setState(() => _fase = _Fase.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, hijo) {
        // Un cambio de tamaño de letra del sistema no puede romper la
        // pantalla: se acompaña, pero con tope.
        final escala = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: escala),
          child: hijo ?? const SizedBox.shrink(),
        );
      },
      home: _raiz(),
    );
  }

  Widget _raiz() {
    // El cruce entre fases se anima acá y no dentro de cada pantalla: así una
    // pantalla nunca sabe qué había antes de ella.
    return _CruceFases(
      child: switch (_fase) {
        _Fase.apertura => PantallaApertura(
            key: const ValueKey('apertura'),
            alTerminar: (haySesion) => setState(
              () => _fase = haySesion ? _Fase.dentro : _Fase.login,
            ),
          ),
        _Fase.login => PantallaLogin(
            key: const ValueKey('login'),
            alEntrar: () => setState(() => _fase = _Fase.dentro),
          ),
        _Fase.dentro => Consumer(
            key: const ValueKey('dentro'),
            builder: (context, ref, _) => ShellPrincipal(
              alSalir: () async {
                await ref.read(authRepoProvider).cerrarSesion();
                if (mounted) setState(() => _fase = _Fase.login);
              },
            ),
          ),
      },
    );
  }
}

class _CruceFases extends StatelessWidget {
  const _CruceFases({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: duracion(context, Movimiento.entrada),
        switchInCurve: Movimiento.muelle,
        switchOutCurve: Movimiento.salida,
        child: child,
      );
}
