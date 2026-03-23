import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'image_path_helper.dart';

class AiPracticeImageHelper {
  static Future<String> createPlaceholderImage({
    String? subject,
    String? category,
  }) async {
    const canvasWidth = 1200.0;
    const canvasHeight = 630.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
    );

    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 24, canvasWidth - 48, canvasHeight - 48),
        const Radius.circular(32),
      ),
      borderPaint,
    );

    final bannerPaint = Paint()..color = const Color(0xFFFF8A00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(72, 72, 240, 72),
        const Radius.circular(24),
      ),
      bannerPaint,
    );

    _paintText(
      canvas,
      text: 'AI 練習題',
      topLeft: const Offset(108, 92),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 180,
    );

    _paintText(
      canvas,
      text: '這是系統自動建立的 AI 練習題佔位圖',
      topLeft: const Offset(72, 200),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 42,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      maxWidth: 900,
    );

    final metaText = [
      if (subject != null && subject.isNotEmpty) '科目：$subject',
      if (category != null && category.isNotEmpty) '分類：$category',
    ].join('    ');

    _paintText(
      canvas,
      text: metaText.isEmpty ? '可加入錯題庫進行後續複習與練習。' : metaText,
      topLeft: const Offset(72, 340),
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      maxWidth: 980,
    );

    _paintText(
      canvas,
      text: '來源：AI 相似題練習',
      topLeft: const Offset(72, 512),
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 24,
        fontWeight: FontWeight.w500,
      ),
      maxWidth: 400,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('無法建立 AI 練習題佔位圖');
    }

    final imagesDir = await ImagePathHelper.getImagesDirectory();
    final fileName = 'ai_practice_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = p.join(imagesDir.path, fileName);
    await File(filePath).writeAsBytes(bytes.buffer.asUint8List());
    return filePath;
  }

  static void _paintText(
    Canvas canvas, {
    required String text,
    required Offset topLeft,
    required TextStyle style,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    textPainter.paint(canvas, topLeft);
  }
}
