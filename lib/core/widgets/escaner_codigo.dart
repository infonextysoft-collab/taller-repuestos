import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/tokens.dart';
import 'campo.dart';

/// Lector de códigos de barras.
///
/// **Siempre** deja escribir el código a mano: si no hay permiso de cámara, o
/// la etiqueta está rota, el trabajo no se frena por eso.
///
/// Devuelve el código leído, o `null` si se canceló.
Future<String?> escanearCodigo(
  BuildContext context, {
  String titulo = 'Escanear código',
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PantallaEscaner(titulo: titulo),
    ),
  );
}

class _PantallaEscaner extends StatefulWidget {
  const _PantallaEscaner({required this.titulo});

  final String titulo;

  @override
  State<_PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<_PantallaEscaner> {
  final MobileScannerController _camara = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  final _aMano = TextEditingController();
  bool _yaLeyo = false;
  String? _problema;

  @override
  void dispose() {
    _camara.dispose();
    _aMano.dispose();
    super.dispose();
  }

  void _devolver(String codigo) {
    if (_yaLeyo || codigo.trim().isEmpty) return;
    _yaLeyo = true;
    Navigator.of(context).pop(codigo.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tono.texto,
      appBar: AppBar(
        backgroundColor: Tono.texto,
        foregroundColor: Colors.white,
        title: Text(widget.titulo),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: () => _camara.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camara,
                  onDetect: (captura) {
                    final valor = captura.barcodes
                        .map((b) => b.rawValue)
                        .firstWhere((v) => v != null && v.isNotEmpty,
                            orElse: () => null);
                    if (valor != null) _devolver(valor);
                  },
                  errorBuilder: (context, error, _) {
                    // Sin cámara o sin permiso: se sigue a mano.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _problema == null) {
                        setState(() => _problema =
                            'No se pudo abrir la cámara. Escribe el código.');
                      }
                    });
                    return const ColoredBox(color: Tono.texto);
                  },
                ),
                const IgnorePointer(child: _Mira()),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Tono.fondo,
            padding: const EdgeInsets.all(Espacio.lg),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_problema != null) ...[
                    Text(
                      _problema!,
                      style: const TextStyle(color: Tono.vino, fontSize: 13),
                    ),
                    const SizedBox(height: Espacio.md),
                  ],
                  Campo(
                    etiqueta: 'O escribilo a mano',
                    controlador: _aMano,
                    ejemplo: '7501234567890',
                    teclado: TextInputType.number,
                    textoAccion: TextInputAction.done,
                    onEnviar: _devolver,
                  ),
                  const SizedBox(height: Espacio.md),
                  FilledButton(
                    onPressed: () => _devolver(_aMano.text),
                    child: const Text('Usar este código'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El recuadro de puntería. Solo trazos: nada que obligue a re-muestrear el
/// fondo de la cámara en cada frame.
class _Mira extends StatelessWidget {
  const _Mira();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 260,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: Redondeo.brNormal,
            border: Border.all(color: Tono.vino, width: 2.5),
          ),
        ),
      );
}
