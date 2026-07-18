import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  // Kontroler untuk mengatur kamera scanner
  final MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false; // Mencegah scan ganda/berulang dalam satu waktu

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arahkan ke QR Code Resi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F3D6F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Widget kamera pemindai dari library mobile_scanner
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_hasScanned) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() {
                    _hasScanned = true; // Kunci scanner agar tidak membaca terus-menerus
                  });
                  // Kembalikan teks/ID hasil scan ke halaman home_screen.dart
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Tambahan desain bingkai kotak pembantu di tengah layar kamera
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}