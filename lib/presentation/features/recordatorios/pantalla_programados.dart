import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/fechas.dart';
import '../../../core/widgets/contenido.dart';
import '../../../domain/entities/recordatorio.dart';
import 'acciones_aviso.dart';
import 'tarjeta_aviso.dart';

/// Lo que todavía no toca, del más cercano al más lejano.
class PantallaProgramados extends ConsumerStatefulWidget {
  const PantallaProgramados({super.key});

  @override
  ConsumerState<PantallaProgramados> createState() =>
      _PantallaProgramadosState();
}

class _PantallaProgramadosState extends ConsumerState<PantallaProgramados> {
  List<Recordatorio> _items = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todos = await ref.read(recordatoriosRepoProvider).listar();
    final hoy = hoyISO();

    if (!mounted) return;
    setState(() {
      _items = todos
          .where((r) => r.activo && r.fecha.compareTo(hoy) > 0)
          .toList();
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refrescoRecordatoriosProvider, (_, _) => _cargar());

    return Scaffold(
      backgroundColor: Tono.fondo2,
      appBar: AppBar(title: const Text('Programados')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: EstadoVacio(
                icono: Icons.event_rounded,
                titulo: 'No hay nada programado',
                detalle: 'Toca el + de Mis avisos para agregar uno.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(
                top: Espacio.lg,
                bottom: Espacio.xxl,
              ),
              children: [
                for (final r in _items)
                  Contenido(
                    padding: const EdgeInsets.fromLTRB(
                      Espacio.lg,
                      0,
                      Espacio.lg,
                      Espacio.md,
                    ),
                    child: TarjetaAviso(
                      recordatorio: r,
                      onTap: () => abrirAviso(context, ref, r),
                      onCumplir: () => cumplirAviso(context, ref, r),
                    ),
                  ),
              ],
            ),
    );
  }
}
