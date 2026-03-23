import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CropImageResult {
  const CropImageResult({
    required this.originalImagePath,
    required this.cropPaths,
  });

  final String originalImagePath;
  final List<String> cropPaths;

  String? get firstCropPath => cropPaths.isEmpty ? null : cropPaths.first;
}

class CropImageHelper {
  static Future<CropImageResult> cropSelectedRegions({
    required String imagePath,
    required List<Rect> rects,
    required Size displaySize,
    List<Path> erasePaths = const [],
    String filePrefix = 'crop',
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('圖片檔案不存在: $imagePath');
    }

    final bytes = await file.readAsBytes();
    var originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('無法解碼圖片');
    }

    originalImage = img.bakeOrientation(originalImage);
    if (erasePaths.isNotEmpty) {
      originalImage = _applyEraseMask(originalImage, displaySize, erasePaths);
    }

    final tempDir = await getTemporaryDirectory();
    final cropPaths = <String>[];

    for (var i = 0; i < rects.length; i++) {
      final croppedImage = _cropRegion(
        image: originalImage,
        rect: rects[i],
        displaySize: displaySize,
      );
      final fileName =
          '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final cropPath = p.join(tempDir.path, fileName);
      await File(cropPath).writeAsBytes(img.encodeJpg(croppedImage));
      cropPaths.add(cropPath);
    }

    return CropImageResult(
      originalImagePath: imagePath,
      cropPaths: cropPaths,
    );
  }

  static img.Image _cropRegion({
    required img.Image image,
    required Rect rect,
    required Size displaySize,
  }) {
    final geometry = _calculateGeometry(
      imageWidth: image.width,
      imageHeight: image.height,
      displaySize: displaySize,
    );

    final left = ((rect.left - geometry.offsetX) * geometry.scale)
        .toInt()
        .clamp(0, image.width - 1);
    final top = ((rect.top - geometry.offsetY) * geometry.scale)
        .toInt()
        .clamp(0, image.height - 1);
    var width = (rect.width * geometry.scale).toInt();
    var height = (rect.height * geometry.scale).toInt();

    width = width.clamp(1, image.width - left);
    height = height.clamp(1, image.height - top);

    return img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }

  static _CropGeometry _calculateGeometry({
    required int imageWidth,
    required int imageHeight,
    required Size displaySize,
  }) {
    final imgAspect = imageWidth / imageHeight;
    final viewAspect = displaySize.width / displaySize.height;

    double actualVisibleWidth;
    double offsetX = 0;
    double offsetY = 0;

    if (viewAspect > imgAspect) {
      actualVisibleWidth = displaySize.height * imgAspect;
      offsetX = (displaySize.width - actualVisibleWidth) / 2;
    } else {
      actualVisibleWidth = displaySize.width;
      final actualVisibleHeight = displaySize.width / imgAspect;
      offsetY = (displaySize.height - actualVisibleHeight) / 2;
    }

    final scale = imageWidth / actualVisibleWidth;

    return _CropGeometry(
      offsetX: offsetX,
      offsetY: offsetY,
      scale: scale,
    );
  }

  static img.Image _applyEraseMask(
    img.Image originalImage,
    Size displaySize,
    List<Path> erasePaths,
  ) {
    final geometry = _calculateGeometry(
      imageWidth: originalImage.width,
      imageHeight: originalImage.height,
      displaySize: displaySize,
    );

    final maskedImage = img.copyResize(
      originalImage,
      width: originalImage.width,
      height: originalImage.height,
    );

    for (final screenPath in erasePaths) {
      final pathMetrics = screenPath.computeMetrics();

      for (final metric in pathMetrics) {
        final pathPoints = <img.Point>[];

        for (double t = 0.0; t <= 1.0; t += 0.01) {
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent == null) continue;

          final screenPoint = tangent.position;
          final pixelX = ((screenPoint.dx - geometry.offsetX) * geometry.scale)
              .toInt()
              .clamp(0, originalImage.width - 1);
          final pixelY = ((screenPoint.dy - geometry.offsetY) * geometry.scale)
              .toInt()
              .clamp(0, originalImage.height - 1);
          pathPoints.add(img.Point(pixelX, pixelY));
        }

        final brushWidth = (30.0 * geometry.scale).toInt().clamp(5, 100);

        for (final point in pathPoints) {
          final radius = brushWidth ~/ 2;
          for (var dy = -radius; dy <= radius; dy++) {
            for (var dx = -radius; dx <= radius; dx++) {
              final px = (point.x + dx).toInt();
              final py = (point.y + dy).toInt();
              if (px < 0 ||
                  px >= maskedImage.width ||
                  py < 0 ||
                  py >= maskedImage.height) {
                continue;
              }

              final distance = math.sqrt(dx * dx + dy * dy);
              if (distance <= radius) {
                maskedImage.setPixel(px, py, img.ColorRgb8(255, 255, 255));
              }
            }
          }
        }
      }
    }

    return maskedImage;
  }
}

class _CropGeometry {
  const _CropGeometry({
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  final double offsetX;
  final double offsetY;
  final double scale;
}
