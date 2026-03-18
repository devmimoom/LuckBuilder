import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

/// PDF 預覽頁面
class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;

  const PdfPreviewPage({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('預覽'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: '錯題本_${DateTime.now().toString().substring(0, 10)}.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => pdfBytes,
        allowPrinting: false, // 使用 AppBar 的列印按鈕，避免功能重複
        allowSharing: false,  // 使用 AppBar 的分享按鈕，避免功能重複
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}
