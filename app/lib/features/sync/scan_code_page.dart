import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../sync/sync_crypto.dart';

/// Scans the sync QR shown on the other device. Returns the code, or null.
/// Android only; the web keeps Paste.
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      // Only a real sync code is accepted; anything else keeps scanning.
      if (raw != null && normalizeSyncCode(raw) != null) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan sync code')),
    body: MobileScanner(onDetect: _onDetect),
  );
}
