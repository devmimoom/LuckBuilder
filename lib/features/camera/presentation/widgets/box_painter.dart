import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/crop_provider.dart';

class SelectionPainter extends CustomPainter {
  final List<Rect> rects;
  final Rect? current;
  final Path? erasePath;  // 當前正在塗掉的路徑
  final List<Path> erasePaths;  // 所有塗掉的路徑
  final EditMode mode;  // 當前模式

  SelectionPainter({
    required this.rects,
    this.current,
    this.erasePath,
    this.erasePaths = const [],
    this.mode = EditMode.select,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == EditMode.select) {
      _paintSelection(canvas, size);
    }
    _paintErase(canvas, size);
  }

  // 繪製框選區域
  void _paintSelection(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = AppColors.highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = AppColors.highlight.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // 繪製所有已存入的框
    for (var rect in rects) {
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);
      _drawCornerMarks(canvas, rect);
    }

    // 繪製當前正在拉的框
    if (current != null) {
      canvas.drawRect(current!, fillPaint);
      canvas.drawRect(current!, boxPaint);
    }
  }

  // 繪製塗掉的區域（視覺反饋）
  void _paintErase(Canvas canvas, Size size) {
    final erasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)  // 半透明白色覆蓋
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30.0  // 筆刷寬度
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final eraseFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // 繪製所有已保存的塗掉路徑
    for (var path in erasePaths) {
      canvas.drawPath(path, erasePaint);
      canvas.drawPath(path, eraseFillPaint);
    }

    // 繪製當前正在塗掉的路徑
    if (erasePath != null && erasePath!.computeMetrics().isNotEmpty) {
      canvas.drawPath(erasePath!, erasePaint);
      canvas.drawPath(erasePath!, eraseFillPaint);
    }
  }

  void _drawCornerMarks(Canvas canvas, Rect rect) {
    final markPaint = Paint()
      ..color = AppColors.highlight
      ..strokeWidth = 3.0;
    
    const length = 10.0;
    // 左上角
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(length, 0), markPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, length), markPaint);
    // 右下角
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-length, 0), markPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -length), markPaint);
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) => true;
}

