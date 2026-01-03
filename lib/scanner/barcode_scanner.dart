import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerWidget extends StatefulWidget {
  const ScannerWidget({super.key});

  @override
  State<ScannerWidget> createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget> {
  bool showScanner = false;
  String? scannedCode;

  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.all],
  );

  void startScanner() {
    setState(() {
      showScanner = true;
      scannedCode = null;
    });
  }

  void stopScanner() {
    controller.stop();
    setState(() {
      showScanner = false;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Scanner"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); 
          },
        ),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showScanner)
              SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue ?? "Unknown";
                      setState(() {
                        scannedCode = code;
                        showScanner = false;
                      });
                      controller.stop();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("QR Code: $code")));
                    }
                  },
                  onDetectError: (error, stackTrace) {
                    log("error: $error   -${stackTrace.toString()}");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "error: $error   -${stackTrace.toString()}",
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, e) {
                    log("Error: $e");
                    return Text("Error: $e");
                  },
                ),
              ),
            if (scannedCode != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Last QR Code: $scannedCode"),
              ),
            ElevatedButton(
              onPressed: startScanner,
              child: const Text("Start QR Scanner"),
            ),
            if (showScanner)
              ElevatedButton(
                onPressed: stopScanner,
                child: const Text("Stop Scanner"),
              ),
          ],
        ),
      ),
    );
  }
}
